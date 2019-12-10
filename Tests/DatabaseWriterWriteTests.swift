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

class DatabaseWriterWriteTests : XCTestCase {
    func testRxWrite() throws {
        func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
            let completable = writer.rx.write { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            try XCTAssertEqual(writer.read(Player.fetchCount), 0)
            _ = try completable.toBlocking(timeout: 1).toArray()
            try XCTAssertEqual(writer.read(Player.fetchCount), 1)
        }
        
        try Test(test)
            .run { try setup(DatabaseQueue()) }
            .runAtPath { try setup(DatabaseQueue(path: $0)) }
            .runAtPath { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteError() throws {
        func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
            let completable = writer.rx.write { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                try db.execute(sql: "THIS IS NOT SQL")
            }
            try XCTAssertEqual(writer.read(Player.fetchCount), 0)
            do {
                _ = try completable.toBlocking(timeout: 1).toArray()
                XCTFail("Expected Error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
            // Transaction has been rollbacked
            try XCTAssertEqual(writer.read(Player.fetchCount), 0)
        }
        
        try Test(test)
            .run { try setup(DatabaseQueue()) }
            .runAtPath { try setup(DatabaseQueue(path: $0)) }
            .runAtPath { try setup(DatabasePool(path: $0)) }
    }
    
    func testRxWriteScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write { db in
                    try Player.createTable(db)
                }
                return writer
            }
            
            func test(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
                do {
                    let completable = writer.rx
                        .write { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) }
                        .do(onCompleted: {
                            dispatchPrecondition(condition: .onQueue(.main))
                        })
                    _ = try completable.toBlocking(timeout: 1).toArray()
                }
                do {
                    let queue = DispatchQueue(label: "test")
                    let completable = writer.rx
                        .write(
                            observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                            updates: { db in try Player(id: 2, name: "Barbara", score: nil).insert(db) })
                        .do(onCompleted: {
                            dispatchPrecondition(condition: .onQueue(queue))
                        })
                    _ = try completable.toBlocking(timeout: 1).toArray()
                }
            }
            
            try Test(test)
                .run { try setup(DatabaseQueue()) }
                .runAtPath { try setup(DatabaseQueue(path: $0)) }
                .runAtPath { try setup(DatabasePool(path: $0)) }
        }
    }
    
    func testRxWriteIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
            }
            return writer
        }
        
        func test(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
            let semaphore = DispatchSemaphore(value: 0)
            let completable = writer.rx.write { db in
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
        
        try Test(test)
            .run { try setup(DatabaseQueue()) }
            .runAtPath { try setup(DatabaseQueue(path: $0)) }
            .runAtPath { try setup(DatabasePool(path: $0)) }
    }
}
