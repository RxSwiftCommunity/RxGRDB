import XCTest
import GRDB
import RxSwift
import RxGRDB

class FetchRequestChangesTests : XCTestCase { }

// MARK: - Changes

extension FetchRequestChangesTests {
    func testRxChanges() throws {
        try Test(testRxChanges)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
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
        
        let requests: [SQLRequest<Row>] = [
            "SELECT * FROM table1",
            "SELECT id, a FROM table1",
            "SELECT table1.id, table1.a, table2.a FROM table1 JOIN table2 ON table1.id = table2.id"]
        
        var changes = requests.map { _ in false }
        for (index, request) in requests.enumerated() {
            request.rx
                .changes(in: writer)
                .subscribe(onNext: { _ in
                    changes[index] = true
                })
                .disposed(by: disposeBag)
        }

        // Subscription immediately triggers an event
        XCTAssertEqual(changes, [true, true, true])
        
        try writer.writeWithoutTransaction { db in
            func reset() { changes = changes.map { _ in false } }
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.inTransaction {
                try db.execute(sql: "INSERT INTO table1 (id, a, b) VALUES (NULL, 0, 0)")
                XCTAssertEqual(changes, [false, false, false])
                return .commit
            }
            XCTAssertEqual(changes, [true, true, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute(sql: "INSERT INTO table2 (id, a, b) VALUES (NULL, 0, 0)")
            XCTAssertEqual(changes, [false, false, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute(sql: "UPDATE table1 SET a = 1")
            XCTAssertEqual(changes, [true, true, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute(sql: "UPDATE table1 SET b = 1")
            XCTAssertEqual(changes, [true, false, false])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute(sql: "UPDATE table2 SET a = 1")
            XCTAssertEqual(changes, [false, false, true])
            
            // Transaction triggers an event for concerned requests
            reset()
            try db.execute(sql: "UPDATE table2 SET b = 1")
            XCTAssertEqual(changes, [false, false, false])
        }
    }
}

// TODO: restore this test, which 1. fails, 2. makes some other tests fails as well (WTF?)
//extension FetchRequestChangesTests {
//    func testChangesRetry() throws {
//        try Test(testChangesRetry)
////            .run { try DatabaseQueue(path: $0) }
//            .run { try DatabasePool(path: $0) }
//    }
//
//    func testChangesRetry(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
//        try writer.write { db in
//            try db.create(table: "table1") { t in
//                t.column("id", .integer).primaryKey()
//            }
//        }
//
//        let request = SQLRequest(sql: "SELECT * FROM table1")
//        var changesCount = 0
//        var needsThrow = false
//        request.rx
//            .changes(in: writer)
//            .map { db in
//                if needsThrow {
//                    needsThrow = false
//                    throw NSError(domain: "RxGRDB", code: 0)
//                }
//            }
//            .retry()
//            .subscribe(onNext: { _ in
//                changesCount += 1
//            })
//            .disposed(by: disposeBag)
//
//        XCTAssertEqual(changesCount, 1)
//
//        try writer.writeWithoutTransaction { db in
//            try db.execute(sql: "INSERT INTO table1 (id) VALUES (NULL)")
//            XCTAssertEqual(changesCount, 2)
//
//            needsThrow = true
//            try db.execute(sql: "INSERT INTO table1 (id) VALUES (NULL)")
//            XCTAssertEqual(changesCount, 3)
//
//            needsThrow = false
//            try db.execute(sql: "INSERT INTO table1 (id) VALUES (NULL)")
//            XCTAssertEqual(changesCount, 4)
//
//            try db.execute(sql: "INSERT INTO table1 (id) VALUES (NULL)")
//            XCTAssertEqual(changesCount, 5)
//        }
//    }
//}

