import XCTest
import GRDB
import RxSwift
@testable import ReactiveGRDB

class TestDatabase<Writer: DatabaseWriter> {
    private let directoryURL: URL
    let writer: Writer
    
    init(_ writer: (String) throws -> Writer) throws {
        directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        self.writer = try writer(directoryURL.appendingPathComponent("db.sqlite").path)
    }
    
    deinit {
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
    
    func testSelectionInfoRxSelection(writer: DatabaseWriter) throws {
        var selectionInfo1: SelectStatement.SelectionInfo! = nil
        var selectionInfo2: SelectStatement.SelectionInfo! = nil
        var selectionInfo3: SelectStatement.SelectionInfo! = nil
        
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
            
            selectionInfo1 = try db.makeSelectStatement("SELECT * FROM table1").selectionInfo
            selectionInfo2 = try db.makeSelectStatement("SELECT id, a FROM table1").selectionInfo
            selectionInfo3 = try db.makeSelectStatement("SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id").selectionInfo
        }
        
        var changed1 = false
        var changed2 = false
        var changed3 = false
        
        selectionInfo1.rx.selection(in: writer).subscribe(onNext: { _ in changed1 = true }).addDisposableTo(disposeBag)
        selectionInfo2.rx.selection(in: writer).subscribe(onNext: { _ in changed2 = true }).addDisposableTo(disposeBag)
        selectionInfo3.rx.selection(in: writer).subscribe(onNext: { _ in changed3 = true }).addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertTrue(changed1)
        XCTAssertTrue(changed2)
        XCTAssertTrue(changed3)
        
        try writer.write { db in
            func reset() {
                changed1 = false
                changed2 = false
                changed3 = false
            }
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.inTransaction {
                try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
                XCTAssertFalse(changed1)
                XCTAssertFalse(changed2)
                XCTAssertFalse(changed3)
                return .commit
            }
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table1 SET a = 1")
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table1 SET b = 1")
            XCTAssertTrue(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table2 SET a = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned selection
            reset()
            try db.execute("UPDATE table2 SET b = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
        }
    }
    
    func testSelectionInfoRxSelection() throws {
        let testQueue = try TestDatabase { try DatabaseQueue(path: $0) }
        try testSelectionInfoRxSelection(writer: testQueue.writer)
        
        let testPool = try TestDatabase { try DatabasePool(path: $0) }
        try testSelectionInfoRxSelection(writer: testPool.writer)
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
        
        var changed1 = false
        var changed2 = false
        var changed3 = false
        
        let request1 = SQLRequest("SELECT * FROM table1")
        let request2 = SQLRequest("SELECT id, a FROM table1")
        let request3 = SQLRequest("SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id")
        
        request1.rx.selection(in: writer).subscribe(onNext: { _ in changed1 = true }).addDisposableTo(disposeBag)
        request2.rx.selection(in: writer).subscribe(onNext: { _ in changed2 = true }).addDisposableTo(disposeBag)
        request3.rx.selection(in: writer).subscribe(onNext: { _ in changed3 = true }).addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertTrue(changed1)
        XCTAssertTrue(changed2)
        XCTAssertTrue(changed3)
        
        try writer.write { db in
            func reset() {
                changed1 = false
                changed2 = false
                changed3 = false
            }
            
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.inTransaction {
                try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
                XCTAssertFalse(changed1)
                XCTAssertFalse(changed2)
                XCTAssertFalse(changed3)
                return .commit
            }
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table1 SET a = 1")
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table1 SET b = 1")
            XCTAssertTrue(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table2 SET a = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute("UPDATE table2 SET b = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
        }
    }
    
    func testRequestRxSelection() throws {
        let testQueue = try TestDatabase { try DatabaseQueue(path: $0) }
        try testRequestRxSelection(writer: testQueue.writer)
        
        let testPool = try TestDatabase { try DatabasePool(path: $0) }
        try testRequestRxSelection(writer: testPool.writer)
    }
    
    func testRequestRxFetchAll(writer: DatabaseWriter) throws {
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
        
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try Person(id: nil, name: "Arthur").insert(db)
            try Person(id: nil, name: "Barbara").insert(db)
        }
        
        let expectations = (UInt(2)...3).map { i -> XCTestExpectation in
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = i
            expectation.assertForOverFulfill = false
            return expectation
        }
        
        let request = Person.order(Column("name"))
        var records: [Person] = []
        request.rx.fetchAll(in: writer)
            .subscribe(onNext: {
                // events happen on the main thread
                XCTAssertTrue(Thread.isMainThread)
                records = $0
                expectations.forEach { $0.fulfill() }
            })
            .addDisposableTo(disposeBag)
        
        // Subscription immediately triggers an event
        XCTAssertEqual(records.map({ $0.name }), ["Arthur", "Barbara"])
        
        try writer.write { db in
            try Person(id: nil, name: "Craig").insert(db)
            wait(for: [expectations[0]], timeout: 1)
            XCTAssertEqual(records.map({ $0.name }), ["Arthur", "Barbara", "Craig"])
            
            try Person.deleteAll(db)
            wait(for: [expectations[1]], timeout: 1)
            XCTAssertEqual(records.map({ $0.name }), [])
        }
    }
    
    func testRequestRxFetchAll() throws {
        let testQueue = try TestDatabase { try DatabaseQueue(path: $0) }
        try testRequestRxFetchAll(writer: testQueue.writer)
        
        let testPool = try TestDatabase { try DatabasePool(path: $0) }
        try testRequestRxFetchAll(writer: testPool.writer)
    }
}
