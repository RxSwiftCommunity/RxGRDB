import XCTest
import GRDB
import RxSwift
@testable import RxGRDB

class ReactiveRequestTests: ReactiveTestCase { }


// MARK: - Changes

extension ReactiveRequestTests {
    func testRxChanges() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxChanges)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxChanges)
    }
    
    func testRxChanges(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .integer)
                t.column("b", .integer)
            }
            try db.create(table: "table2") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .integer)
                t.column("b", .integer)
            }
        }
        
        let requests = [
            SQLRequest("SELECT * FROM table1"),
            SQLRequest("SELECT id, a FROM table1"),
            SQLRequest("SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id")]
        
        var changes = requests.map { _ in false }
        for (index, request) in requests.enumerated() {
            request.rx
                .changes(in: writer)
                .subscribe(onNext: { _ in changes[index] = true })
                .addDisposableTo(disposeBag)
        }
        
        // Subscription immediately triggers an event
        XCTAssertEqual(changes, [true, true, true])
        
        try writer.write { db in
            func reset() { changes = changes.map { _ in false } }
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.inTransaction {
                try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
                XCTAssertEqual(changes, [false, false, false])
                return .commit
            }
            XCTAssertEqual(changes, [true, true, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertEqual(changes, [false, false, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table1 SET a = 1")
            XCTAssertEqual(changes, [true, true, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table1 SET b = 1")
            XCTAssertEqual(changes, [true, false, false])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table2 SET a = 1")
            XCTAssertEqual(changes, [false, false, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table2 SET b = 1")
            XCTAssertEqual(changes, [false, false, false])
        }
    }
}

extension ReactiveRequestTests {
    func testChangesRetry() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testChangesRetry)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testChangesRetry)
    }
    
    func testChangesRetry(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let request = SQLRequest("SELECT * FROM table1")
        var changesCount = 0
        var needsThrow = false
        request.rx
            .changes(in: writer)
            .map { db in
                if needsThrow {
                    needsThrow = false
                    throw NSError(domain: "RxGRDB", code: 0)
                }
            }
            .retry()
            .subscribe(onNext: { _ in
                changesCount += 1
            })
            .addDisposableTo(disposeBag)
        
        XCTAssertEqual(changesCount, 1)
        
        try writer.write { db in
            try db.execute("INSERT INTO table1 (id) VALUES (NULL)")
            XCTAssertEqual(changesCount, 2)
            
            needsThrow = true
            try db.execute("INSERT INTO table1 (id) VALUES (NULL)")
            XCTAssertEqual(changesCount, 3)
            
            needsThrow = false
            try db.execute("INSERT INTO table1 (id) VALUES (NULL)")
            XCTAssertEqual(changesCount, 4)
            
            try db.execute("INSERT INTO table1 (id) VALUES (NULL)")
            XCTAssertEqual(changesCount, 5)
        }
    }
}


// MARK: - Count

extension ReactiveTypedRequestTests {
    func testRxFetchCount() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchCount)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchCount)
    }
    
    func testRxFetchCount(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        struct Record : TableMapping { static let databaseTableName = "table1" }
        let request = Record.all()
        var count: Int = 0xdeadbeef
        request.rx
            .fetchCount(in: writer)
            .subscribe(onNext: {
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                count = $0
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(count, 1)
        
        // Transaction triggers an asynchronous event
        try writer.write { try $0.execute("INSERT INTO table1 (id) VALUES (NULL)") }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 2)
    }
}

extension ReactiveTypedRequestTests {
    func testRxFetchCountRetry() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchCountRetry)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchCountRetry)
    }
    
    func testRxFetchCountRetry(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second one on retry.
        
        // Subscribe to a request
        struct Record : TableMapping { static let databaseTableName = "table1" }
        let request = Record.all()
        var eventsCount = 0
        var needsThrow = false
        request.rx
            .fetchCount(in: writer)
            .map { db in
                if needsThrow {
                    needsThrow = false
                    throw NSError(domain: "RxGRDB", code: 0)
                }
            }
            .retry()
            .subscribe(onNext: {
                eventsCount += 1
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        XCTAssertEqual(eventsCount, 1)
        
        needsThrow = true
        try writer.write { try $0.execute("INSERT INTO table1 (id) VALUES (NULL)") }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(eventsCount, 2)
    }
}
