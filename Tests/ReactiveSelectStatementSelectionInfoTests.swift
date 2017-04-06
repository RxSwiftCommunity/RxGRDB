import XCTest
import GRDB
import RxSwift
@testable import RxGRDB

class ReactiveSelectStatementSelectionInfoTests: ReactiveTestCase { }

extension ReactiveSelectStatementSelectionInfoTests {
    func testChanges() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testChanges)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testChanges)
    }
    
    func testChanges(writer: DatabaseWriter) throws {
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

extension ReactiveSelectStatementSelectionInfoTests {
    func testChangesRetry() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testChangesRetry)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testChangesRetry)
    }
    
    func testChangesRetry(writer: DatabaseWriter) throws {
        var selectionInfo: SelectStatement.SelectionInfo! = nil
        try writer.write { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            selectionInfo = try db.makeSelectStatement("SELECT * FROM table1").selectionInfo
        }
        
        var changesCount = 0
        var needsThrow = false
        selectionInfo.rx
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

