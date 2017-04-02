import XCTest
import GRDB
import RxSwift
@testable import ReactiveGRDB

class ReactiveTypedRequestTests: ReactiveTestCase { }

extension ReactiveTypedRequestTests {
    func testRxFetchAll() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAll)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAll)
    }
    
    func testRxFetchAll(writer: DatabaseWriter) throws {
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
        
        try writer.write { db in
            // Transaction triggers an asynchronous event
            try Person(id: nil, name: "Craig").insert(db)
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(records.map({ $0.name }), ["Arthur", "Barbara", "Craig"])
        }
    }
}

extension ReactiveTypedRequestTests {
    func testRxFetchOne() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOne)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOne)
    }
    
    func testRxFetchOne(writer: DatabaseWriter) throws {
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
        
        try writer.write { db in
            // Transaction triggers an asynchronous event
            try db.execute("UPDATE persons SET name = ?", arguments: ["Barbara"])
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(record!.name, "Barbara")
        }
    }
}

extension ReactiveTypedRequestTests {
    func testRxDiff() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxDiff)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxDiff)
    }
    
    func testRxDiff(writer: DatabaseWriter) throws {
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
        var persons: RequestResults<Person>? = nil
        var diff: RequestDiff<Person>? = nil
        request.rx
            .diff(in: writer)
            .subscribe(onNext: { (newPersons, newDiff) in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                persons = newPersons
                diff = newDiff
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(persons!.count, 1)
        XCTAssertEqual(persons![0].name, "Arthur")
        switch diff! {
        case .snapshot:
            break
        default:
            XCTFail("Unexpected diff")
        }
        
        try writer.write { db in
            // Transaction triggers an asynchronous event
            try db.execute("UPDATE persons SET name = ?", arguments: ["Barbara"])
            waitForExpectations(timeout: 1, handler: nil)
            
            XCTAssertEqual(persons!.count, 1)
            XCTAssertEqual(persons![0].name, "Barbara")
            switch diff! {
            case .changes(let changes):
                XCTAssertEqual(changes.count, 1)
                XCTAssertEqual(changes[0].record.name, "Barbara")
                switch changes[0].kind {
                case .update(let indexPath, let changes):
                    XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
                    XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
                default:
                    XCTFail("Unexpected diff")
                }
            default:
                XCTFail("Unexpected diff")
            }
        }
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
