import XCTest
import GRDB
import RxSwift
@testable import ReactiveGRDB

class TestDatabase<Writer: DatabaseWriter> {
    private let directoryURL: URL
    private var writer: Writer!
    
    init(_ writer: (String) throws -> Writer) throws {
        directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        self.writer = try writer(directoryURL.appendingPathComponent("db.sqlite").path)
    }
    
    @discardableResult
    func test(with testClosure: (Writer) throws -> ()) rethrows -> Self {
        try testClosure(writer)
        return self
    }
    
    deinit {
        self.writer = nil
        try! FileManager.default.removeItem(at: directoryURL)
    }
}

class ReactiveRequestTests: XCTestCase {
    var disposeBag: DisposeBag! = nil
    
    override func setUp() {
        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        disposeBag = nil
    }
}

extension ReactiveRequestTests {
    func testSelectionInfoRxSelection() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testSelectionInfoRxSelection)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testSelectionInfoRxSelection)
    }
    
    func testSelectionInfoRxSelection(writer: DatabaseWriter) throws {
        var selectionInfos: [SelectStatement.SelectionInfo] = []
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
            
            try selectionInfos.append(db.makeSelectStatement("SELECT * FROM table1").selectionInfo)
            try selectionInfos.append(db.makeSelectStatement("SELECT id, a FROM table1").selectionInfo)
            try selectionInfos.append(db.makeSelectStatement("SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id").selectionInfo)
        }
        
        var changes = selectionInfos.map { _ in false }
        for (index, selectionInfo) in selectionInfos.enumerated() {
            selectionInfo.rx
                .selection(in: writer)
                .subscribe(onNext: { _ in changes[index] = true })
                .addDisposableTo(disposeBag)
        }
        
        // Subscription immediately triggers an event
        XCTAssertEqual(changes, [true, true, true])
        
        try writer.write { db in
            func reset() { changes = changes.map { _ in false } }
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.inTransaction {
                try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
                XCTAssertEqual(changes, [false, false, false])
                return .commit
            }
            XCTAssertEqual(changes, [true, true, true])
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertEqual(changes, [false, false, true])
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table1 SET a = 1")
            XCTAssertEqual(changes, [true, true, true])
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table1 SET b = 1")
            XCTAssertEqual(changes, [true, false, false])
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table2 SET a = 1")
            XCTAssertEqual(changes, [false, false, true])
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table2 SET b = 1")
            XCTAssertEqual(changes, [false, false, false])
        }
    }
}

extension ReactiveRequestTests {
    func testRequestRxSelection() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRequestRxSelection)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRequestRxSelection)
    }
    
    func testRequestRxSelection(writer: DatabaseWriter) throws {
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
                .selection(in: writer)
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
    func testRequestRxFetchAll() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRequestRxFetchAll)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRequestRxFetchAll)
    }

    func testRequestRxFetchAll(writer: DatabaseWriter) throws {
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
        
        // Subscribe tp a request
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
    
    class Person: Record {
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
}
