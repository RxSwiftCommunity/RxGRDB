import XCTest
import GRDB
import RxSwift
import RxGRDB

class ValueObservationTests : XCTestCase { }

extension ValueObservationTests {
    
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
        let request = SQLRequest<Row>(sql: "SELECT * FROM table1")
        let observation = ValueObservation.tracking(request, fetch: { db -> ([String], Int) in
            let strings = try String.fetchAll(db, sql: "SELECT a FROM table1")
            let int = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM table2")!
            return (strings, int)
        })
        
        // 1 (startImmediately parameter is true by default)
        observation.rx
            .fetch(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        
        try writer.writeWithoutTransaction { db in
            // 2: modify observed requests
            try db.inTransaction {
                try db.execute(sql: "INSERT INTO table1 (a) VALUES ('foo')")
                try db.execute(sql: "INSERT INTO table1 (a) VALUES ('bar')")
                try db.execute(sql: "INSERT INTO table2 DEFAULT VALUES")
                return .commit
            }
            
            // Still 2: table2 is not observed
            try db.execute(sql: "INSERT INTO table2 DEFAULT VALUES")
            
            // 3: modify observed request
            try db.execute(sql: "DELETE FROM table1")
        }
        wait(for: recorder, timeout: 1)
        
        for (event, value) in zip(recorder.recordedEvents, expectedValues) {
            XCTAssertEqual(event.element!.0, value.0)
            XCTAssertEqual(event.element!.1, value.1)
        }
    }
}

extension ValueObservationTests {
    
    // This is a regression test that fails in v0.8.0
    func testSubscriptionOffMainThread() throws {
        try Test(testSubscriptionOffMainThread)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testSubscriptionOffMainThread(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.write { db in
            try db.create(table: "t") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let expectedValues: [Int] = [0, 1, 2]
        let recorder = EventRecorder<Int>(expectedEventCount: expectedValues.count)
        let request = SQLRequest<Int>(sql: "SELECT COUNT(*) FROM t")

        let initialFetchExpectation = expectation(description: "initial fetch")
        initialFetchExpectation.assertForOverFulfill = false
        let observation = ValueObservation.tracking(request, fetch: { db -> Int in
            initialFetchExpectation.fulfill()
            return try request.fetchOne(db)!
        })

        DispatchQueue.global().async {
            observation.rx
                .fetch(in: writer)
                .subscribe { event in
                    // events are expected on the main thread by default
                    assertMainQueue()
                    recorder.on(event)
                }
                .disposed(by: disposeBag)
        }
        
        // wait until we have fetched initial value before we perform database changes
        wait(for: [initialFetchExpectation], timeout: 1)
        try writer.writeWithoutTransaction { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        wait(for: recorder, timeout: 1)
        for (event, value) in zip(recorder.recordedEvents, expectedValues) {
            XCTAssertEqual(event.element!, value)
        }
    }
}

extension ValueObservationTests {
    
    // This is a regression test that fails in v0.9.0
    func testSubscriptionFromMainThread() throws {
        try Test(testSubscriptionFromMainThread)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testSubscriptionFromMainThread(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.write { db in
            try db.create(table: "t") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        var disposable: Disposable? {
            willSet { disposable?.dispose() }
            didSet { disposable?.disposed(by: disposeBag) }
        }
        
        let request = SQLRequest<Int>(sql: "SELECT COUNT(*) FROM t")
        
        let expectation1 = expectation(description: "1st subscription")
        expectation1.expectedFulfillmentCount = 2
        var count1: Int? = nil
        request.rx.fetchOne(in: writer)
            .subscribe(onNext: {
                XCTAssertTrue(Thread.isMainThread)
                expectation1.fulfill()
                count1 = $0
            })
            .disposed(by: disposeBag)
        XCTAssertEqual(count1, 0) // synchronous emission of the 1st event

        try writer.write { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        var count2: Int? = nil
        request.rx.fetchOne(in: writer)
            .subscribe(onNext: {
                XCTAssertTrue(Thread.isMainThread)
                count2 = $0
            })
            .disposed(by: disposeBag)
        XCTAssertEqual(count2, 1) // synchronous emission of the 1st event
        
        waitForExpectations(timeout: 1, handler: nil)
    }
}

extension ValueObservationTests {
    
    // This is a documentation test for https://github.com/RxSwiftCommunity/RxGRDB/issues/52
    func testDontBlockMainThread() throws {
        try Test(testDontBlockMainThread)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testDontBlockMainThread(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        var requestExecutionCount = 0
        writer.add(function: DatabaseFunction("register", argumentCount: 0, pure: false, function: { _ in
            requestExecutionCount += 1
            return nil
        }))
        
        try writer.write { db in
            try db.create(table: "t") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        var disposable: Disposable? {
            willSet { disposable?.dispose() }
            didSet { disposable?.disposed(by: disposeBag) }
        }
        
        let request = SQLRequest<Int>(sql: "SELECT COUNT(*), register() FROM t")
        
        let expectation = self.expectation(description: "subscription")
        expectation.expectedFulfillmentCount = 1
        request.rx
            .fetchOne(in: writer)
            .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .userInitiated))
            .subscribe(onNext: { _ in
                XCTAssertTrue(Thread.isMainThread)
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        XCTAssertEqual(requestExecutionCount, 0) // main thread has NOT been blocked by initial fetch
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(requestExecutionCount, 1) // initial fetch has been performed
    }
}
