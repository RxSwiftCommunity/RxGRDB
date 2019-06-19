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

class DatabaseWriterWriteTests : XCTestCase { }

extension DatabaseWriterWriteTests {
    func testRxWrite() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxWrite).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWrite).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWrite<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single = writer.rx.write { db in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
        }
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        let _: Void = try single.toBlocking(timeout: 1).single()
        try XCTAssertEqual(writer.read(Player.fetchCount), 1)
    }
}

extension DatabaseWriterWriteTests {
    func testRxWriteReturnValue() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxWriteReturnValue).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteReturnValue).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteReturnValue<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single = writer.rx.write { db -> Int in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            return try Player.fetchCount(db)
        }
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}

@available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
extension DatabaseWriterWriteTests {
    func testRxWriteScheduler() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        try Test(testRxWriteScheduler).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteScheduler).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteScheduler<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        do {
            let single = writer.rx
                .write { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) }
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(.main))
                })
            _ = try single.toBlocking(timeout: 1).single()
        }
        do {
            let queue = DispatchQueue(label: "test")
            let single = writer.rx
                .write(
                    observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                    updates: { db in try Player(id: 2, name: "Barbara", score: nil).insert(db) })
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                })
            _ = try single.toBlocking(timeout: 1).single()
        }
    }
}

extension DatabaseWriterWriteTests {
    func testRxWriteIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        try Test(testRxWriteIsAsynchronous).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteIsAsynchronous).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteIsAsynchronous<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let single = writer.rx.write { db -> Int in
            // Make sure this block executes asynchronously
            semaphore.wait()
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
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
