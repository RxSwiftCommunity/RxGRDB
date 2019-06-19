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

class DatabaseWriterWriteCompletableTests : XCTestCase { }

extension DatabaseWriterWriteCompletableTests {
    func testRxWriteCompletable() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        try Test(testRxWriteCompletable).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteCompletable).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteCompletable<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let completable = writer.rx.writeCompletable { db in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
        }
        try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        _ = try completable.toBlocking(timeout: 1).toArray()
        try XCTAssertEqual(writer.read(Player.fetchCount), 1)
    }
}

@available(OSX 10.12, *)
extension DatabaseWriterWriteCompletableTests {
    func testRxWriteCompletableScheduler() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        try Test(testRxWriteCompletableScheduler).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteCompletableScheduler).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteCompletableScheduler<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        do {
            let completable = writer.rx
                .writeCompletable { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) }
                .do(onCompleted: {
                    dispatchPrecondition(condition: .onQueue(.main))
                })
            _ = try completable.toBlocking(timeout: 1).toArray()
        }
        do {
            let queue = DispatchQueue(label: "test")
            let completable = writer.rx
                .writeCompletable(
                    observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                    updates: { db in try Player(id: 2, name: "Barbara", score: nil).insert(db) })
                .do(onCompleted: {
                    dispatchPrecondition(condition: .onQueue(queue))
                })
            _ = try completable.toBlocking(timeout: 1).toArray()
        }
    }
}

extension DatabaseWriterWriteCompletableTests {
    func testRxWriteCompletableIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter & ReactiveCompatible>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        try Test(testRxWriteCompletableIsAsynchronous).run { try setup(DatabaseQueue(path: $0)) }
        try Test(testRxWriteCompletableIsAsynchronous).run { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteCompletableIsAsynchronous<Writer: DatabaseWriter & ReactiveCompatible>(writer: Writer, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let completable = writer.rx.writeCompletable { db in
            // Make sure this block executes asynchronously
            semaphore.wait()
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
        }
        
        _ = try completable
            .do(onSubscribed: {
                semaphore.signal()
            })
            .toBlocking(timeout: 1)
            .toArray()
    }
}
