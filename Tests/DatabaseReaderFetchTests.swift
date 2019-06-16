import GRDB
import RxBlocking
import RxGRDB
import RxSwift
import XCTest

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int?
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer)
        }
    }
}

class DatabaseReaderFetchTests : XCTestCase { }

extension DatabaseReaderFetchTests {
    func testRxFetch() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            return writer
        }
        try Test(testRxFetch).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFetch).run { try setup(DatabasePool(path: $0)) }
        try Test(testRxFetch).run { try setup(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    func testRxFetch<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        let single = reader.rx.fetch { db in try Player.fetchCount(db) }
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}

@available(OSX 10.12, *)
extension DatabaseReaderFetchTests {
    func testRxFetchScheduler() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            return writer
        }
        try Test(testRxFetchScheduler).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFetchScheduler).run { try setup(DatabasePool(path: $0)) }
        try Test(testRxFetchScheduler).run { try setup(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    func testRxFetchScheduler<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        do {
            let single = reader.rx
                .fetch { db in try Player.fetchCount(db) }
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(.main))
                })
            _ = try single.toBlocking(timeout: 1).toArray()
        }
        do {
            let queue = DispatchQueue(label: "test")
            let single = reader.rx
                .fetch(
                    scheduler: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                    value: { db in try Player.fetchCount(db) })
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                })
            _ = try single.toBlocking(timeout: 1).toArray()
        }
    }
}

extension DatabaseReaderFetchTests {
    func testRxFetchIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            return writer
        }
        try Test(testRxFetchIsAsynchronous).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxFetchIsAsynchronous).run { try setup(DatabasePool(path: $0)) }
        try Test(testRxFetchIsAsynchronous).run { try setup(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    func testRxFetchIsAsynchronous<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let single = reader.rx.fetch { db -> Int in
            // Make sure this block executes asynchronously
            semaphore.wait()
            return try Player.fetchCount(db)
        }
        
        let count = try single
            .asObservable()
            .do(onSubscribed: {
                semaphore.signal()
            })
            .toBlocking(timeout: 1)
            .single()
        XCTAssertEqual(count, 1)
    }
}

extension DatabaseReaderFetchTests {
    func testRxFetchIsReadonly() throws {
        try Test(testRxFetchIsReadonly).run { try DatabaseQueue(path: $0) }
        try Test(testRxFetchIsReadonly).run { try DatabasePool(path: $0) }
        try Test(testRxFetchIsReadonly).run { try DatabasePool(path: $0).makeSnapshot() }
    }
    
    func testRxFetchIsReadonly<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        let single = reader.rx.fetch { db in
            try Player.createTable(db)
        }
        
        let sequence = single
            .asObservable()
            .toBlocking(timeout: 1)
            .materialize()
        switch sequence {
        case .completed:
            XCTFail("Expected error")
        case let .failed(elements: elements, error: error):
            XCTAssertTrue(elements.isEmpty)
            guard let dbError = error as? DatabaseError else {
                XCTFail("Unexpected error: \(error)")
                return
            }
            XCTAssertEqual(dbError.resultCode, .SQLITE_READONLY)
        }
    }
}
