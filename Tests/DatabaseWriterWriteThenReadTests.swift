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

class DatabaseWriterWriteThenReadTests : XCTestCase { }

extension DatabaseWriterWriteThenReadTests {
    func testRxWriteThenRead() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxWriteThenRead).run { try setup(DatabaseQueue()) }
        try Test(testRxWriteThenRead).runAtPath { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteThenRead).runAtPath { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteThenRead<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single: Single<Int> = writer.rx.write(
            updates: { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) },
            thenRead: { (db, _) in try Player.fetchCount(db) })
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}

extension DatabaseWriterWriteThenReadTests {
    func testRxWriteValueThenRead() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxWriteValueThenRead).run { try setup(DatabaseQueue()) }
        try Test(testRxWriteValueThenRead).runAtPath { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteValueThenRead).runAtPath { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteValueThenRead<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single: Single<Int> = writer.rx.write(
            updates: { db -> Int in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                return 42
        },
            thenRead: { (db, int) in try int + Player.fetchCount(db) })
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 43)
    }
}

extension DatabaseWriterWriteThenReadTests {
    func testRxWriteThenReadScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
                try writer.write { db in
                    try Player.createTable(db)
                }
                return writer
            }
            try Test(testRxWriteThenReadScheduler).run { try setup(DatabaseQueue()) }
            try Test(testRxWriteThenReadScheduler).runAtPath { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxWriteThenReadScheduler).runAtPath { try setup(DatabasePool(path: $0)) }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxWriteThenReadScheduler<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        do {
            let single = writer.rx
                .write(
                    updates: { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) },
                    thenRead: { (db, _) in try Player.fetchCount(db) })
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
                    updates: { db in try Player(id: 2, name: "Barbara", score: nil).insert(db) },
                    thenRead: { (db, _) in try Player.fetchCount(db) })
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                })
            _ = try single.toBlocking(timeout: 1).single()
        }
    }
}

extension DatabaseWriterWriteThenReadTests {
    func testRxWriteThenReadIsReadOnly() throws {
        try Test(testRxWriteThenReadIsReadOnly).run { DatabaseQueue() }
        try Test(testRxWriteThenReadIsReadOnly).runAtPath { try DatabaseQueue(path: $0) }
        try Test(testRxWriteThenReadIsReadOnly).runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxWriteThenReadIsReadOnly<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single = writer.rx.write(
            updates: { _ in },
            thenRead: { (db, _) in try Player.createTable(db) })
        
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
