import XCTest
import GRDB
import RxSwift
import RxGRDB

class FetchTokenTests : XCTestCase { }

extension FetchTokenTests {
    
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
        let request = SQLRequest<Row>("SELECT * FROM table1")
        
        // 1 (startImmediately parameter is true by default)
        AnyDatabaseWriter(writer).rx
            .fetchTokens(in: [request])
            .mapFetch() { db -> ([String], Int) in
                let strings = try String.fetchAll(db, "SELECT a FROM table1")
                let int = try Int.fetchOne(db, "SELECT COUNT(*) FROM table2")!
                return (strings, int)
            }
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
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

extension FetchTokenTests {
    
    // This is a regression test that fails in v0.8.0
    func testAsynchronousSubscription() throws {
        try Test(testAsynchronousSubscription)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testAsynchronousSubscription(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.write { db in
            try db.create(table: "t") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let expectedValues: [Int] = [0, 1, 2]
        let recorder = EventRecorder<Int>(expectedEventCount: expectedValues.count)
        let request = SQLRequest<Int>("SELECT COUNT(*) FROM t")
        
        let initialFetchExpectation = expectation(description: "initial fetch")
        initialFetchExpectation.assertForOverFulfill = false

        DispatchQueue.global().async {
            AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request])
                .mapFetch() { db -> Int in
                    initialFetchExpectation.fulfill()
                    return try request.fetchOne(db)!
                }
                .subscribe { event in
                    // events are expected on the main thread by default
                    assertMainQueue()
                    recorder.on(event)
                }
                .disposed(by: disposeBag)
        }
        
        // wait until we have fetched initial value before we perform database changes
        wait(for: [initialFetchExpectation], timeout: 1)
        try writer.write { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
            try db.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        wait(for: recorder, timeout: 1)
        for (event, value) in zip(recorder.recordedEvents, expectedValues) {
            XCTAssertEqual(event.element!, value)
        }
    }
}

