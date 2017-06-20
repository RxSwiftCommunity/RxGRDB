import XCTest
import GRDB
import RxSwift
@testable import RxGRDB

class RxTypedRequestDiffTests: RxGRDBTestCase { }

extension RxTypedRequestDiffTests {
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
        var event: RequestEvent<Person>? = nil
        request.rx
            .diff(in: writer)
            .subscribe(onNext: { (newPersons, newEvent) in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                persons = newPersons
                event = newEvent
                expectation.fulfill()
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(persons!.count, 1)
        XCTAssertEqual(persons![0].name, "Arthur")
        switch event! {
        case .snapshot:
            break
        default:
            XCTFail("Unexpected event")
        }
        
        // Transaction triggers an asynchronous event
        try writer.write { try $0.execute("UPDATE persons SET name = ?", arguments: ["Barbara"]) }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(persons!.count, 1)
        XCTAssertEqual(persons![0].name, "Barbara")
        switch event! {
        case .changes(let changes):
            XCTAssertEqual(changes.count, 1)
            XCTAssertEqual(changes[0].record.name, "Barbara")
            switch changes[0].kind {
            case .update(let indexPath, let changes):
                XCTAssertEqual(indexPath, IndexPath(indexes: [0, 0]))
                XCTAssertEqual(changes, ["name": "Arthur".databaseValue])
            default:
                XCTFail("Unexpected change")
            }
        default:
            XCTFail("Unexpected event")
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
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
