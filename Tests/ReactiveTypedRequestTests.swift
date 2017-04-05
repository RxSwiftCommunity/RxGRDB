import XCTest
import GRDB
import RxSwift
@testable import RxGRDB

class ReactiveTypedRequestTests: ReactiveTestCase { }

// MARK: - RowConvertible

extension ReactiveTypedRequestTests {
    func testRxFetchAllRecords() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllRecords)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllRecords)
    }
    
    func testRxFetchAllRecords(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
            try Person(id: nil, name: "Barbara").insert(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        let request = Person.order(Column("name"))
        var records: [Person] = []
        request.rx
            .fetchAll(in: writer)
            .subscribe(onNext: {
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                records = $0
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(records.map({ $0.name }), ["Arthur", "Barbara"])
        
        // Transaction triggers an asynchronous event
        try writer.write { try Person(id: nil, name: "Craig").insert($0) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(records.map({ $0.name }), ["Arthur", "Barbara", "Craig"])
    }
}

extension ReactiveTypedRequestTests {
    func testRxFetchOneRecord() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneRecord)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneRecord)
    }
    
    func testRxFetchOneRecord(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        let request = Person.all()
        var record: Person? = nil
        request.rx
            .fetchOne(in: writer)
            .subscribe(onNext: {
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                record = $0
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(record!.name, "Arthur")
        
        // Transaction triggers an asynchronous event
        try writer.write { try $0.execute("UPDATE persons SET name = ?", arguments: ["Barbara"]) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(record!.name, "Barbara")
    }
}

// MARK: - Row

extension ReactiveTypedRequestTests {
    func testRxFetchAllRows() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllRows)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllRows)
    }
    
    func testRxFetchAllRows(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
            try Person(id: nil, name: "Barbara").insert(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        let request = SQLRequest("SELECT * FROM persons ORDER BY name").bound(to: Row.self)
        var rows: [Row] = []
        request.rx
            .fetchAll(in: writer)
            .subscribe(onNext: {
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                rows = $0
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(rows.map({ $0.value(named: "name") as String }), ["Arthur", "Barbara"])
        
        // Transaction triggers an asynchronous event
        try writer.write { try Person(id: nil, name: "Craig").insert($0) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(rows.map({ $0.value(named: "name") as String }), ["Arthur", "Barbara", "Craig"])
    }
}

extension ReactiveTypedRequestTests {
    func testRxFetchOneRow() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneRow)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneRow)
    }
    
    func testRxFetchOneRow(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        let request = SQLRequest("SELECT * FROM persons").bound(to: Row.self)
        var row: Row? = nil
        request.rx
            .fetchOne(in: writer)
            .subscribe(onNext: {
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                row = $0
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(row!.value(named: "name") as String, "Arthur")
        
        // Transaction triggers an asynchronous event
        try writer.write { try $0.execute("UPDATE persons SET name = ?", arguments: ["Barbara"]) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(row!.value(named: "name") as String, "Barbara")
    }
}


// MARK: - DatabaseValue

extension ReactiveTypedRequestTests {
    func testRxFetchAllDatabaseValues() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllDatabaseValues)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllDatabaseValues)
    }
    
    func testRxFetchAllDatabaseValues(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
            try Person(id: nil, name: "Barbara").insert(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        let request = SQLRequest("SELECT name FROM persons ORDER BY name").bound(to: String.self)
        var names: [String] = []
        request.rx
            .fetchAll(in: writer)
            .subscribe(onNext: {
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                names = $0
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(names, ["Arthur", "Barbara"])
        
        // Transaction triggers an asynchronous event
        try writer.write { try Person(id: nil, name: "Craig").insert($0) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(names, ["Arthur", "Barbara", "Craig"])
    }
}

extension ReactiveTypedRequestTests {
    func testRxFetchOneDatabaseValue() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneDatabaseValue)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneDatabaseValue)
    }
    
    func testRxFetchOneDatabaseValue(writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        let request = SQLRequest("SELECT COUNT(*) FROM persons").bound(to: Int.self)
        var count: Int? = nil
        request.rx
            .fetchOne(in: writer)
            .subscribe(onNext: {
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                count = $0
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(count!, 1)
        
        // Transaction triggers an asynchronous event
        try writer.write { try Person(id: nil, name: "Barbara").insert($0) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count!, 2)
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
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second on transaction.
        
        // Subscribe to a request
        let request = Person.all()
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
        try writer.write { try Person(id: nil, name: "Barbara").insert($0) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 2)
    }
}


private class Person: Record {
    var id: Int64?
    var name: String
    
    init(id: Int64?, name: String) {
        self.id = id
        self.name = name
        super.init()
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        super.init(row: row)
    }
    
    override class var databaseTableName: String { return "persons" }
    
    override var persistentDictionary: [String : DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
