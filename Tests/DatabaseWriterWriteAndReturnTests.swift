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

class DatabaseWriterWriteAndReturnTests : XCTestCase { }

extension DatabaseWriterWriteAndReturnTests {
    func testRxWriteAndReturn() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxWriteAndReturn).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteAndReturn).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteAndReturn<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single = writer.rx.writeAndReturn { db in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
        }
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        let _: Void = try single.toBlocking(timeout: 1).single()
        try XCTAssertEqual(writer.read(Player.fetchCount), 1)
    }
}

extension DatabaseWriterWriteAndReturnTests {
    func testRxWriteAndReturnValue() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxWriteAndReturnValue).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteAndReturnValue).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteAndReturnValue<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let single = writer.rx.writeAndReturn { db -> Int in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            return try Player.fetchCount(db)
        }
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 1)
    }
}

extension DatabaseWriterWriteAndReturnTests {
    func testRxWriteAndReturnScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
                try writer.write { db in
                    try Player.createTable(db)
                }
                return writer
            }
            try Test(testRxWriteAndReturnScheduler).run { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxWriteAndReturnScheduler).run { try setup(DatabasePool(path: $0)) }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxWriteAndReturnScheduler<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        do {
            let single = writer.rx
                .writeAndReturn { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) }
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(.main))
                })
            _ = try single.toBlocking(timeout: 1).single()
        }
        do {
            let queue = DispatchQueue(label: "test")
            let single = writer.rx
                .writeAndReturn(
                    observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                    updates: { db in try Player(id: 2, name: "Barbara", score: nil).insert(db) })
                .do(onSuccess: { _ in
                    dispatchPrecondition(condition: .onQueue(queue))
                })
            _ = try single.toBlocking(timeout: 1).single()
        }
    }
}

extension DatabaseWriterWriteAndReturnTests {
    func testRxWriteAndReturnIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        try Test(testRxWriteAndReturnIsAsynchronous).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteAndReturnIsAsynchronous).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteAndReturnIsAsynchronous<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let single = writer.rx.writeAndReturn { db -> Int in
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
