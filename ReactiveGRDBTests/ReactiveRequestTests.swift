import XCTest
import GRDB
import RxSwift
@testable import ReactiveGRDB

class ReactiveRequestTests: XCTestCase {
    var disposeBag: DisposeBag! = nil
    
    override func setUp() {
        disposeBag = DisposeBag()
    }
    
    override func tearDown() {
        disposeBag = nil
    }
    
    func testSelectionInfoSelection() throws {
        let dbQueue = DatabaseQueue()
        
        var selectionInfo1: SelectStatement.SelectionInfo! = nil
        var selectionInfo2: SelectStatement.SelectionInfo! = nil
        var selectionInfo3: SelectStatement.SelectionInfo! = nil
        
        try dbQueue.inDatabase { db in
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
        
        selectionInfo1.rx.selection(in: dbQueue).subscribe(onNext: { changed1 = true }).addDisposableTo(disposeBag)
        selectionInfo2.rx.selection(in: dbQueue).subscribe(onNext: { changed2 = true }).addDisposableTo(disposeBag)
        selectionInfo3.rx.selection(in: dbQueue).subscribe(onNext: { changed3 = true }).addDisposableTo(disposeBag)
        
        XCTAssertTrue(changed1)
        XCTAssertTrue(changed2)
        XCTAssertTrue(changed3)
        
        try dbQueue.inDatabase { db in
            func reset() {
                changed1 = false
                changed2 = false
                changed3 = false
            }
            
            reset()
            try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("UPDATE table1 SET a = 1")
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("UPDATE table1 SET b = 1")
            XCTAssertTrue(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
            
            reset()
            try db.execute("UPDATE table2 SET a = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("UPDATE table2 SET b = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
        }
    }
    
    func testRequestSelection() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.inDatabase { db in
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
        
        request1.rx.selection(in: dbQueue).subscribe(onNext: { changed1 = true }).addDisposableTo(disposeBag)
        request2.rx.selection(in: dbQueue).subscribe(onNext: { changed2 = true }).addDisposableTo(disposeBag)
        request3.rx.selection(in: dbQueue).subscribe(onNext: { changed3 = true }).addDisposableTo(disposeBag)
        
        XCTAssertTrue(changed1)
        XCTAssertTrue(changed2)
        XCTAssertTrue(changed3)
        
        try dbQueue.inDatabase { db in
            func reset() {
                changed1 = false
                changed2 = false
                changed3 = false
            }
            
            reset()
            try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("UPDATE table1 SET a = 1")
            XCTAssertTrue(changed1)
            XCTAssertTrue(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("UPDATE table1 SET b = 1")
            XCTAssertTrue(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
            
            reset()
            try db.execute("UPDATE table2 SET a = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertTrue(changed3)
            
            reset()
            try db.execute("UPDATE table2 SET b = 1")
            XCTAssertFalse(changed1)
            XCTAssertFalse(changed2)
            XCTAssertFalse(changed3)
        }
    }
    
}
