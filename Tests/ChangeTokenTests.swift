import XCTest
import GRDB
import RxSwift
import RxGRDB

class ChangeTokenTests : XCTestCase { }

extension ChangeTokenTests {
    func testFetch() throws {
        try Test(testFetch)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testFetch(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.write { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
                t.column("a", .text).notNull()
            }
            try db.create(table: "table2") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let expectedValues: [([String], Int)] = [
            ([], 0),
            (["foo", "bar"], 1),
            ([], 2)
        ]
        let recorder = EventRecorder<([String], Int)>(expectedEventCount: expectedValues.count)
        let request = SQLRequest("SELECT * FROM table1")
        
        // 1 (synchronizedStart parameter is true by default)
        AnyDatabaseWriter(writer).rx
            .changeTokens(in: [request])
            .mapFetch() { db -> ([String], Int) in
                let strings = try String.fetchAll(db, "SELECT a FROM table1")
                let int = try Int.fetchOne(db, "SELECT COUNT(*) FROM table2")!
                return (strings, int)
            }
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        
        try writer.write { db in
            // 2: modify observed requests
            try db.inTransaction {
                try db.execute("INSERT INTO table1 (a) VALUES ('foo')")
                try db.execute("INSERT INTO table1 (a) VALUES ('bar')")
                try db.execute("INSERT INTO table2 DEFAULT VALUES")
                return .commit
            }
            
            // Still 2: table2 is not observed
            try db.execute("INSERT INTO table2 DEFAULT VALUES")
            
            // 3: modify observed request
            try db.execute("DELETE FROM table1")
        }
        wait(for: recorder, timeout: 1)
        
        for (event, value) in zip(recorder.recordedEvents, expectedValues) {
            XCTAssertEqual(event.element!.0, value.0)
            XCTAssertEqual(event.element!.1, value.1)
        }
    }
}
