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
    
    // MARK: -
    
    func testReadObservable() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) throws {
            let single = reader.rx.read(value: { db in
                try Player.fetchCount(db)
            })
            let value = try single.toBlocking(timeout: 1).single()
            XCTAssertEqual(value, 0)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadObservableError() throws {
        func test(reader: DatabaseReader) throws {
            let single = reader.rx.read(value: { db in
                try Row.fetchAll(db, sql: "THIS IS NOT SQL")
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
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadObservableIsAsynchronous() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) throws {
            let disposeBag = DisposeBag()
            withExtendedLifetime(disposeBag) {
                let expectation = self.expectation(description: "")
                let semaphore = DispatchSemaphore(value: 0)
                reader.rx
                    .read(value: { db in
                        try Player.fetchCount(db)
                    })
                    .subscribe(
                        onSuccess: { _ in
                            semaphore.wait()
                            expectation.fulfill()
                    },
                        onError: { error in XCTFail("Unexpected error \(error)") })
                    .disposed(by: disposeBag)
                
                semaphore.signal()
                waitForExpectations(timeout: 1, handler: nil)
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadObservableDefaultScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            
            func test(reader: DatabaseReader) {
                let disposeBag = DisposeBag()
                withExtendedLifetime(disposeBag) {
                    let expectation = self.expectation(description: "")
                    reader.rx
                        .read(value: { db in
                            try Player.fetchCount(db)
                        })
                        .subscribe(
                            onSuccess: { _ in
                                dispatchPrecondition(condition: .onQueue(.main))
                                expectation.fulfill()
                        },
                            onError: { error in XCTFail("Unexpected error \(error)") })
                        .disposed(by: disposeBag)
                    
                    waitForExpectations(timeout: 1, handler: nil)
                }
            }
            
            try Test(test)
                .run { try setUp(DatabaseQueue()) }
                .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    // MARK: -
    
    func testReadObservableCustomScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            
            func test(reader: DatabaseReader) {
                let disposeBag = DisposeBag()
                withExtendedLifetime(disposeBag) {
                    let queue = DispatchQueue(label: "test")
                    let expectation = self.expectation(description: "")
                    reader.rx
                        .read(
                            observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"),
                            value: { db in
                                try Player.fetchCount(db)
                        })
                        .subscribe(
                            onSuccess: { _ in
                                dispatchPrecondition(condition: .onQueue(queue))
                                expectation.fulfill()
                        },
                            onError: { error in XCTFail("Unexpected error \(error)") })
                        .disposed(by: disposeBag)
                    
                    waitForExpectations(timeout: 1, handler: nil)
                }
            }
            
            try Test(test)
                .run { try setUp(DatabaseQueue()) }
                .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
                .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    // MARK: -
    
    func testReadObservableIsReadonly() throws {
        func test(reader: DatabaseReader) throws {
            let single = reader.rx.read(value: { db in
                try Player.createTable(db)
            })
            do {
                _ = try single.toBlocking(timeout: 1).single()
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
}
