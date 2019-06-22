import XCTest
import GRDB
import RxSwift
import RxGRDB

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int?
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer)
        }
    }
}

class ValueObservationTests : XCTestCase { }

extension ValueObservationTests {
    
    func testFetch() throws {
        try Test(testFetch)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
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
        
        struct Info: Equatable {
            var strings: [String]
            var count: Int
        }
        let request = SQLRequest<Row>(sql: "SELECT * FROM table1")
        let observation = ValueObservation.tracking(request, fetch: { db -> Info in
            let strings = try String.fetchAll(db, sql: "SELECT a FROM table1")
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM table2")!
            return Info(strings: strings, count: count)
        })
        
        // 1 (startImmediately parameter is true by default)
        let testSubject = ReplaySubject<Info>.createUnbounded()
        observation.rx
            .observe(in: writer)
            .subscribe(testSubject)
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
        
        try XCTAssertEqual(
            testSubject
                .take(3)
                .toBlocking(timeout: 1)
                .toArray(),
            [
                Info(strings: [], count: 0),
                Info(strings: ["foo", "bar"], count: 1),
                Info(strings: [], count: 2),
            ])
    }
}

extension ValueObservationTests {
    func testRxObserveDefaultScheduling() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            try Test(testRxObserveDefaultScheduling).run { try setup(DatabaseQueue()) }
            try Test(testRxObserveDefaultScheduling).runAtPath { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxObserveDefaultScheduling).runAtPath { try setup(DatabasePool(path: $0)) }
            try Test(testRxObserveDefaultScheduling).runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxObserveDefaultScheduling<Reader: DatabaseReader>(reader: Reader, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let observation = Player.observationForCount()
        let testSubject = ReplaySubject<Int>.createUnbounded()
        observation.rx
            .observe(in: reader)
            .do(onNext: { _ in
                semaphore.signal()
                dispatchPrecondition(condition: .onQueue(.main))
            })
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        // Result must have been received synchronously
        semaphore.wait()
        _ = try testSubject.take(1).toBlocking(timeout: 1).toArray()
    }
}

extension ValueObservationTests {
    func testRxObserveDefaultSchedulingSubscribedOffMainThread() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            try Test(testRxObserveDefaultSchedulingSubscribedOffMainThread).run { try setup(DatabaseQueue()) }
            try Test(testRxObserveDefaultSchedulingSubscribedOffMainThread).runAtPath { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxObserveDefaultSchedulingSubscribedOffMainThread).runAtPath { try setup(DatabasePool(path: $0)) }
            try Test(testRxObserveDefaultSchedulingSubscribedOffMainThread).runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxObserveDefaultSchedulingSubscribedOffMainThread<Reader: DatabaseReader>(reader: Reader, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let observation = Player.observationForCount()
        let testSubject = ReplaySubject<Int>.createUnbounded()
        DispatchQueue.global().async {
            observation.rx
                .observe(in: reader)
                .do(onNext: { _ in
                    // Result must be received asynchronously
                    semaphore.wait()
                    dispatchPrecondition(condition: .onQueue(.main))
                })
                .subscribe(testSubject)
                .disposed(by: disposeBag)
            semaphore.signal()
        }
        
        _ = try testSubject.take(1).toBlocking(timeout: 1).toArray()
    }
}

extension ValueObservationTests {
    func testRxObserveDefaultSchedulingStartLater() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            try Test(testRxObserveDefaultSchedulingStartLater).run { try setup(DatabaseQueue()) }
            try Test(testRxObserveDefaultSchedulingStartLater).runAtPath { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxObserveDefaultSchedulingStartLater).runAtPath { try setup(DatabasePool(path: $0)) }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxObserveDefaultSchedulingStartLater<Writer: DatabaseWriter>(writer: Writer, disposeBag: DisposeBag) throws {
        let observation = Player.select(max(Player.Columns.name), as: String.self).observationForFirst()
        let testSubject = ReplaySubject<String?>.createUnbounded()
        observation.rx
            .observe(in: writer as DatabaseReader, startImmediately: false)
            .do(onNext: { _ in
                dispatchPrecondition(condition: .onQueue(.main))
            })
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try writer.writeWithoutTransaction { db in
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            try Player(id: 2, name: "Barbara", score: nil).insert(db)
        }
        let names = try testSubject.take(2).toBlocking(timeout: 1).toArray()
        XCTAssertEqual(names, ["Arthur", "Barbara"])
    }
}

extension ValueObservationTests {
    func testRxObserveSchedulingAsync() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            try Test(testRxObserveSchedulingAsync).run { try setup(DatabaseQueue()) }
            try Test(testRxObserveSchedulingAsync).runAtPath { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxObserveSchedulingAsync).runAtPath { try setup(DatabasePool(path: $0)) }
            try Test(testRxObserveSchedulingAsync).runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxObserveSchedulingAsync<Reader: DatabaseReader>(reader: Reader, disposeBag: DisposeBag) throws {
        let queue = DispatchQueue(label: "test")
        var observation = Player.observationForCount()
        observation.scheduling = .async(onQueue: queue, startImmediately: true)
        let observable = observation.rx
            .observe(in: reader)
            .do(onNext: { _ in
                dispatchPrecondition(condition: .onQueue(queue))
            })
        
        _ = try observable.take(1).toBlocking(timeout: 1).toArray()
    }
}

extension ValueObservationTests {
    func testRxObserveSchedulingAsyncOnMainQueue() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            try Test(testRxObserveSchedulingAsyncOnMainQueue).run { try setup(DatabaseQueue()) }
            try Test(testRxObserveSchedulingAsyncOnMainQueue).runAtPath { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxObserveSchedulingAsyncOnMainQueue).runAtPath { try setup(DatabasePool(path: $0)) }
            try Test(testRxObserveSchedulingAsyncOnMainQueue).runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxObserveSchedulingAsyncOnMainQueue<Reader: DatabaseReader>(reader: Reader, disposeBag: DisposeBag) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db in
            // First fetch must be performed asynchronously
            semaphore.wait()
        })
        observation.scheduling = .async(onQueue: .main, startImmediately: true)
        let observable = observation.rx
            .observe(in: reader)
            .do(onNext: { _ in
                dispatchPrecondition(condition: .onQueue(.main))
            })
        semaphore.signal()
        
        _ = try observable.take(1).toBlocking(timeout: 1).toArray()
    }
}

extension ValueObservationTests {
    func testRxObserveScheduler() throws {
        if #available(OSX 10.12, iOS 10.0, watchOS 3.0, *) {
            func setup<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
                try writer.write(Player.createTable)
                return writer
            }
            try Test(testRxObserveScheduler).run { try setup(DatabaseQueue()) }
            try Test(testRxObserveScheduler).runAtPath { try setup(DatabaseQueue(path: $0)) }
            try Test(testRxObserveScheduler).runAtPath { try setup(DatabasePool(path: $0)) }
            try Test(testRxObserveScheduler).runAtPath { try setup(DatabasePool(path: $0)).makeSnapshot() }
        }
    }
    
    @available(OSX 10.12, iOS 10.0, watchOS 3.0, *)
    func testRxObserveScheduler<Reader: DatabaseReader>(reader: Reader, disposeBag: DisposeBag) throws {
        let observation = Player.observationForCount()
        let queue = DispatchQueue(label: "test")
        let observable = observation.rx
            .observe(
                in: reader,
                observeOn: SerialDispatchQueueScheduler(queue: queue, internalSerialQueueName: "test"))
            .do(onNext: { _ in
                dispatchPrecondition(condition: .onQueue(queue))
            })
        _ = try observable.take(1).toBlocking(timeout: 1).toArray()
    }
}

extension ValueObservationTests {
    
    // This is a regression test that fails in v0.8.0
    func testSubscriptionOffMainThread() throws {
        try Test(testSubscriptionOffMainThread)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testSubscriptionOffMainThread(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.write { db in
            try db.create(table: "t") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let request: SQLRequest<Int> = "SELECT COUNT(*) FROM t"
        
        let initialFetchExpectation = expectation(description: "initial fetch")
        initialFetchExpectation.assertForOverFulfill = false
        let observation = ValueObservation.tracking(request, fetch: { db -> Int in
            initialFetchExpectation.fulfill()
            return try request.fetchOne(db)!
        })
        
        let testSubject = ReplaySubject<Int>.createUnbounded()
        DispatchQueue.global().async {
            observation.rx
                .observe(in: writer)
                .subscribe(testSubject)
                .disposed(by: disposeBag)
        }
        
        // wait until we have fetched initial value before we perform database changes
        wait(for: [initialFetchExpectation], timeout: 1)
        try writer.writeWithoutTransaction { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        }
        
        let counts = try testSubject.take(3).toBlocking().toArray()
        XCTAssertEqual(counts, [0, 1, 2])
    }
}

extension ValueObservationTests {
    
    // This is a regression test that fails in v0.9.0
    func testSubscriptionFromMainThread() throws {
        try Test(testSubscriptionFromMainThread)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testSubscriptionFromMainThread(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.write { db in
            try db.create(table: "t") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        
        let request: SQLRequest<Int> = "SELECT COUNT(*) FROM t"
        
        let expectation1 = expectation(description: "1st subscription")
        expectation1.expectedFulfillmentCount = 2
        var count1: Int? = nil
        request.rx.observeFirst(in: writer)
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
        request.rx.observeFirst(in: writer)
            .subscribe(onNext: {
                XCTAssertTrue(Thread.isMainThread)
                count2 = $0
            })
            .disposed(by: disposeBag)
        XCTAssertEqual(count2, 1) // synchronous emission of the 1st event
        
        waitForExpectations(timeout: 1, handler: nil)
    }
}
