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

class DatabaseReaderReadTests : XCTestCase {
    func testRxJoiner() {
        // Make sure `rx` joiner is available in various contexts
        func f1(_ reader: DatabasePool) {
            _ = reader.rx.read(value: { db in })
        }
        func f2(_ reader: DatabaseQueue) {
            _ = reader.rx.read(value: { db in })
        }
        func f3(_ reader: DatabaseSnapshot) {
            _ = reader.rx.read(value: { db in })
        }
        func f4<Reader: DatabaseReader>(_ reader: Reader) {
            _ = reader.rx.read(value: { db in })
        }
        func f5(_ reader: DatabaseReader) {
            _ = reader.rx.read(value: { db in })
        }
    }
    
    func testRxRead() throws {
        func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            return writer
        }
        
        func test(reader: DatabaseReader, disposeBag: DisposeBag) throws {
            let single = reader.rx.read { db in try Player.fetchCount(db) }
            let count = try single.toBlocking(timeout: 1).single()
            XCTAssertEqual(count, 1)
        }
        
        try Test(test)
            .run { try setup(DatabaseQueue()) }
            .runAtPath { try setup(DatabaseQueue(path: $0)) }
            .runAtPath { try setup(DatabasePool(path: $0)) }
            .runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    func testRxReadScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write { db in
                    try Player.createTable(db)
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                }
                return writer
            }
            
            func test(reader: DatabaseReader, disposeBag: DisposeBag) throws {
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
            
            try Test(test)
                .run { try setup(DatabaseQueue()) }
                .runAtPath { try setup(DatabaseQueue(path: $0)) }
                .runAtPath { try setup(DatabasePool(path: $0)) }
                .runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    func testRxReadIsAsynchronous() throws {
        func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write { db in
                try Player.createTable(db)
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            }
            return writer
        }
        
        func test(reader: DatabaseReader, disposeBag: DisposeBag) throws {
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
        
        try Test(test)
            .run { try setup(DatabaseQueue()) }
            .runAtPath { try setup(DatabaseQueue(path: $0)) }
            .runAtPath { try setup(DatabasePool(path: $0)) }
            .runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    func testRxReadIsReadonly() throws {
        func test(reader: DatabaseReader, disposeBag: DisposeBag) throws {
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
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
            .runAtPath { try DatabasePool(path: $0).makeSnapshot() }
    }
}
