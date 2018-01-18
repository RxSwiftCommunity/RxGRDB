import XCTest
import GRDB
import RxSwift
import RxGRDB

class DatabaseWriterTests : XCTestCase { }


// MARK: - Changes

extension DatabaseWriterTests {
    func testRxChanges() throws {
        try Test(testRxChanges)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxChanges(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
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
            SQLRequest("SELECT a FROM table1"),
            SQLRequest("SELECT table1.a, table2.b FROM table1, table2")]
        
        let recorder = EventRecorder<Void>(expectedEventCount: 5)
        
        // 1 (startImmediately parameter is true by default)
        AnyDatabaseWriter(writer).rx // ReactiveCompatible is unavailable: use AnyDatabaseWriter to get .rx
            .changes(in: requests)
            .map { _ in }
            .subscribe(recorder)
            .disposed(by: disposeBag)
        
        try writer.write { db in
            // 2 (modify both requests)
            try db.inTransaction {
                try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
                try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
                return .commit
            }
            
            // still 2 (modifying ignored columns)
            try db.execute("UPDATE table1 SET b = 1")
            try db.execute("UPDATE table2 SET a = 1")
            
            // 3 (modify both requests)
            try db.inTransaction {
                try db.execute("DELETE FROM table1")
                try db.execute("DELETE FROM table2")
                return .commit
            }
            
            // 4 (modify both request)
            try db.execute("INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
            
            // 5 (modify one request)
            try db.execute("INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
        }

        wait(for: recorder, timeout: 1)
    }
}
