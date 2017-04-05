import XCTest
import GRDB
import RxSwift
@testable import RxGRDB

class ReactiveSelectStatementSelectionInfoTests: ReactiveTestCase { }

extension ReactiveSelectStatementSelectionInfoTests {
    func testRxSelection() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxSelection)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxSelection)
    }
    
    func testRxSelection(writer: DatabaseWriter) throws {
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
                .changes(in: writer)
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

