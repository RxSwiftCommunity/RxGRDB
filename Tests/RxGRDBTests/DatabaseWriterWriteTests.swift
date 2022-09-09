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
    func testRxJoiner() {
        // Make sure `rx` joiner is available in various contexts
        func f1(_ writer: DatabasePool) {
            _ = writer.rx.write(updates: { db in })
        }
        func f2(_ writer: DatabaseQueue) {
            _ = writer.rx.write(updates: { db in })
        }
        func f4<Writer: DatabaseWriter>(_ writer: Writer) {
            _ = writer.rx.write(updates: { db in })
        }
        func f5(_ writer: DatabaseWriter) {
            _ = writer.rx.write(updates: { db in })
        }
    }
    
    // MARK: - Write
    
    func testWriteObservable() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(updates: { db -> Int in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                return try Player.fetchCount(db)
            })
            let count = try single.toBlocking(timeout: 1).single()
            XCTAssertEqual(count, 1)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWriteObservableAsCompletable() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let completable = writer.rx
                .write(updates: { db -> Int in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                    return try Player.fetchCount(db)
                })
                .asCompletable()
            _ = try completable.toBlocking(timeout: 1).last()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWriteObservableError() throws {
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(updates: { db in
                try db.execute(sql: "THIS IS NOT SQL")
            })
            do {
                _ = try single.toBlocking(timeout: 1).single()
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testWriteObservableErrorRollbacksTransaction() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(updates: { db in
                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                try db.execute(sql: "THIS IS NOT SQL")
            })
            do {
                _ = try single.toBlocking(timeout: 1).single()
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
            let count = try writer.read(Player.fetchCount)
            XCTAssertEqual(count, 0)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWriteObservableIsAsynchronous() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let disposeBag = DisposeBag()
            withExtendedLifetime(disposeBag) {
                let expectation = self.expectation(description: "")
                let semaphore = DispatchSemaphore(value: 0)
                writer.rx
                    .write(updates: { db in
                        try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                    })
                    .subscribe(
                        onSuccess: {
                            semaphore.wait()
                            expectation.fulfill()
                        },
                        onFailure: { error in XCTFail("Unexpected error \(error)") })
                    .disposed(by: disposeBag)
                
                semaphore.signal()
                waitForExpectations(timeout: 1, handler: nil)
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testWriteObservableDefaultScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            
            func test(writer: DatabaseWriter) {
                let disposeBag = DisposeBag()
                withExtendedLifetime(disposeBag) {
                    let expectation = self.expectation(description: "")
                    writer.rx
                        .write(updates: { db in
                            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                        })
                        .subscribe(
                            onSuccess: { _ in
                                dispatchPrecondition(condition: .onQueue(.main))
                                expectation.fulfill()
                            },
                            onFailure: { error in XCTFail("Unexpected error \(error)") })
                        .disposed(by: disposeBag)
                    
                    waitForExpectations(timeout: 1, handler: nil)
                }
            }
            
            try Test(test)
                .run { try setUp(DatabaseQueue()) }
                .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
        }
    }
    
    // MARK: -
    
    func testWriteObservableCustomScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            
            func test(writer: DatabaseWriter) {
                let disposeBag = DisposeBag()
                withExtendedLifetime(disposeBag) {
                    let queue = DispatchQueue(label: "test")
                    let expectation = self.expectation(description: "")
                    writer.rx
                        .write(
                            observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                            updates: { db in
                                try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                            })
                        .subscribe(
                            onSuccess: { _ in
                                dispatchPrecondition(condition: .onQueue(queue))
                                expectation.fulfill()
                            },
                            onFailure: { error in XCTFail("Unexpected error \(error)") })
                        .disposed(by: disposeBag)
                    
                    waitForExpectations(timeout: 1, handler: nil)
                }
            }
            
            try Test(test)
                .run { try setUp(DatabaseQueue()) }
                .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
        }
    }
    
    // MARK: - WriteThenRead
    
    func testWriteThenReadObservable() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(
                updates: { db in try Player(id: 1, name: "Arthur", score: 1000).insert(db) },
                thenRead: { db, _ in try Player.fetchCount(db) })
            let count = try single.toBlocking(timeout: 1).single()
            XCTAssertEqual(count, 1)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWriteThenReadObservableIsReadonly() throws {
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(
                updates: { _ in },
                thenRead: { db, _ in try Player.createTable(db) })
            do {
                _ = try single.toBlocking(timeout: 1).single()
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: -
    
    func testWriteThenReadObservableWriteError() throws {
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(
                updates: { db in try db.execute(sql: "THIS IS NOT SQL") },
                thenRead: { _, _ in })
            do {
                _ = try single.toBlocking(timeout: 1).single()
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testWriteThenReadObservableWriteErrorRollbacksTransaction() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(
                updates: { db in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                    try db.execute(sql: "THIS IS NOT SQL")
                },
                thenRead: { _, _ in })
            do {
                _ = try single.toBlocking(timeout: 1).single()
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
            let count = try writer.read(Player.fetchCount)
            XCTAssertEqual(count, 0)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    // MARK: -
    
    func testWriteThenReadObservableReadError() throws {
        func test(writer: DatabaseWriter) throws {
            let single = writer.rx.write(
                updates: { _ in },
                thenRead: { db, _ in try Row.fetchAll(db, sql: "THIS IS NOT SQL") })
            do {
                _ = try single.toBlocking(timeout: 1).single()
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test)
            .run { try DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: -
    
    func testWriteThenReadObservableDefaultScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            
            func test(writer: DatabaseWriter) {
                let disposeBag = DisposeBag()
                withExtendedLifetime(disposeBag) {
                    let expectation = self.expectation(description: "")
                    writer.rx
                        .write(
                            updates: { _ in },
                            thenRead: { _, _ in })
                        .subscribe(
                            onSuccess: { _ in
                                dispatchPrecondition(condition: .onQueue(.main))
                                expectation.fulfill()
                            },
                            onFailure: { error in XCTFail("Unexpected error \(error)") })
                        .disposed(by: disposeBag)
                    
                    waitForExpectations(timeout: 1, handler: nil)
                }
            }
            
            try Test(test)
                .run { try setUp(DatabaseQueue()) }
                .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
        }
    }
    
    // MARK: -
    
    func testWriteThenReadObservableCustomScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            
            func test(writer: DatabaseWriter) {
                let disposeBag = DisposeBag()
                withExtendedLifetime(disposeBag) {
                    let queue = DispatchQueue(label: "test")
                    let expectation = self.expectation(description: "")
                    writer.rx
                        .write(
                            observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                            updates: { _ in },
                            thenRead: { _, _ in })
                        .subscribe(
                            onSuccess: { _ in
                                dispatchPrecondition(condition: .onQueue(queue))
                                expectation.fulfill()
                            },
                            onFailure: { error in XCTFail("Unexpected error \(error)") })
                        .disposed(by: disposeBag)
                    
                    waitForExpectations(timeout: 1, handler: nil)
                }
            }
            
            try Test(test)
                .run { try setUp(DatabaseQueue()) }
                .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
        }
    }
}
