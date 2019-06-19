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

class DatabaseReaderReadTests : XCTestCase { }

extension DatabaseReaderReadTests {
    func testRxRead() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            return writer
        }
        try Test(testRxRead).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxRead).run { try setup(DatabasePool(path: $0)) }
        try Test(testRxRead).run { try setup(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    func testRxRead<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        let single = reader.rx.read { db in try Player.fetchCount(db) }
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}

extension DatabaseReaderReadTests {
    func testRxReadScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
                try writer.write { db in
                    try Player.createTable(db)
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                }
                return writer
            }
            try Test(testRxReadScheduler).run { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxReadScheduler).run { try setup(DatabasePool(path: $0)) }
            try Test(testRxReadScheduler).run { try setup(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxReadScheduler<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        do {
            let single = reader.rx
                .read { db in try Player.fetchCount(db) }
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(.main))
                })
            _ = try single.toBlocking(timeout: 1).toArray()
        }
        do {
            let queue = DispatchQueue(label: "test")
            let single = reader.rx
                .read(
                    observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                    value: { db in try Player.fetchCount(db) })
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                })
            _ = try single.toBlocking(timeout: 1).toArray()
        }
    }
}

extension DatabaseReaderReadTests {
    func testRxReadIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            return writer
        }
        try Test(testRxReadIsAsynchronous).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxReadIsAsynchronous).run { try setup(DatabasePool(path: $0)) }
        try Test(testRxReadIsAsynchronous).run { try setup(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    func testRxReadIsAsynchronous<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let single = reader.rx.read { db -> Int in
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

extension DatabaseReaderReadTests {
    func testRxReadIsReadonly() throws {
        try Test(testRxReadIsReadonly).run { try DatabaseQueue(path: $0) }
        try Test(testRxReadIsReadonly).run { try DatabasePool(path: $0) }
        try Test(testRxReadIsReadonly).run { try DatabasePool(path: $0).makeSnapshot() }
    }
    
    func testRxReadIsReadonly<Reader: DatabaseReader & ReactiveCompatible>(reader: Reader, disposeBag: DisposeBag) throws {
        let single = reader.rx.read { db in
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
