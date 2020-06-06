import XCTest
import GRDB
import RxSwift
import RxGRDB

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int?
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer)
        }
    }
}

class ValueObservationTests : XCTestCase {
    
    // MARK: - Default Scheduler
    
    func testDefaultSchedulerChangesNotifications() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let disposeBag = DisposeBag()
            try withExtendedLifetime(disposeBag) {
                let testSubject = ReplaySubject<Int>.createUnbounded()
                ValueObservation
                    .tracking(Player.fetchCount)
                    .rx.observe(in: writer)
                    .subscribe(testSubject)
                    .disposed(by: disposeBag)
                
                try writer.writeWithoutTransaction { db in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                    
                    try db.inTransaction {
                        try Player(id: 2, name: "Barbara", score: 750).insert(db)
                        try Player(id: 3, name: "Craig", score: 500).insert(db)
                        return .commit
                    }
                }
                
                let expectedElements = [0, 1, 3]
                if writer is DatabaseQueue {
                    let elements = try testSubject
                        .take(expectedElements.count)
                        .toBlocking(timeout: 1).toArray()
                    XCTAssertEqual(elements, expectedElements)
                } else {
                    let elements = try testSubject
                        .takeUntil(.inclusive, predicate: { $0 == expectedElements.last })
                        .toBlocking(timeout: 1).toArray()
                    assertValueObservationRecordingMatch(recorded: elements, expected: expectedElements)
                }
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testDefaultSchedulerFirstValueIsEmittedAsynchronously() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let disposeBag = DisposeBag()
            withExtendedLifetime(disposeBag) {
                let expectation = self.expectation(description: "")
                let semaphore = DispatchSemaphore(value: 0)
                ValueObservation
                    .tracking(Player.fetchCount)
                    .rx.observe(in: writer)
                    .subscribe(onNext: { _ in
                        semaphore.wait()
                        expectation.fulfill()
                    })
                    .disposed(by: disposeBag)
                
                semaphore.signal()
                waitForExpectations(timeout: 1, handler: nil)
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testDefaultSchedulerError() throws {
        func test(writer: DatabaseWriter) throws {
            let observable = ValueObservation
                .tracking { try $0.execute(sql: "THIS IS NOT SQL") }
                .rx.observe(in: writer)
            let result = observable.toBlocking().materialize()
            switch result {
            case .completed:
                XCTFail("Expected error")
            case let .failed(elements: _, error: error):
                XCTAssertNotNil(error as? DatabaseError)
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: - Immediate Scheduler
    
    func testImmediateSchedulerChangesNotifications() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let disposeBag = DisposeBag()
            try withExtendedLifetime(disposeBag) {
                let testSubject = ReplaySubject<Int>.createUnbounded()
                ValueObservation
                    .tracking(Player.fetchCount)
                    .rx.observe(in: writer, scheduling: .immediate)
                    .subscribe(testSubject)
                    .disposed(by: disposeBag)
                
                try writer.writeWithoutTransaction { db in
                    try Player(id: 1, name: "Arthur", score: 1000).insert(db)
                    
                    try db.inTransaction {
                        try Player(id: 2, name: "Barbara", score: 750).insert(db)
                        try Player(id: 3, name: "Craig", score: 500).insert(db)
                        return .commit
                    }
                }
                
                let expectedElements = [0, 1, 3]
                if writer is DatabaseQueue {
                    let elements = try testSubject
                        .take(expectedElements.count)
                        .toBlocking(timeout: 1).toArray()
                    XCTAssertEqual(elements, expectedElements)
                } else {
                    let elements = try testSubject
                        .takeUntil(.inclusive, predicate: { $0 == expectedElements.last })
                        .toBlocking(timeout: 1).toArray()
                    assertValueObservationRecordingMatch(recorded: elements, expected: expectedElements)
                }
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testImmediateSchedulerEmitsFirstValueSynchronously() throws {
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(writer: DatabaseWriter) throws {
            let disposeBag = DisposeBag()
            withExtendedLifetime(disposeBag) {
                let semaphore = DispatchSemaphore(value: 0)
                ValueObservation
                    .tracking(Player.fetchCount)
                    .rx.observe(in: writer, scheduling: .immediate)
                    .subscribe(onNext: { _ in
                        semaphore.signal()
                    })
                    .disposed(by: disposeBag)
                
                semaphore.wait()
            }
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
    }
    
    func testImmediateSchedulerError() throws {
        func test(writer: DatabaseWriter) throws {
            let observable = ValueObservation
                .tracking { try $0.execute(sql: "THIS IS NOT SQL") }
                .rx.observe(in: writer, scheduling: .immediate)
            let result = observable.toBlocking().materialize()
            switch result {
            case .completed:
                XCTFail("Expected error")
            case let .failed(elements: _, error: error):
                XCTAssertNotNil(error as? DatabaseError)
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    func testIssue780() throws {
        func test(dbPool: DatabasePool) throws {
            struct Entity: Codable, FetchableRecord, PersistableRecord, Equatable {
                var id: Int64
                var name: String
            }
            try dbPool.write { db in
                try db.create(table: "entity") { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("name", .text)
                }
            }
            let observation = ValueObservation.tracking(Entity.fetchAll)
            let entities = try dbPool.rx
                .write { db in try Entity(id: 1, name: "foo").insert(db) }
                .asCompletable()
                .andThen(observation.rx.observe(in: dbPool, scheduling: .immediate))
                .take(1)
                .toBlocking(timeout: 1)
                .single()
            XCTAssertEqual(entities, [Entity(id: 1, name: "foo")])
        }
        try Test(test).runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
    }
    
    // MARK: - Utils
    
    /// This test checks the fundamental promise of ValueObservation by
    /// comparing recorded values with expected values.
    ///
    /// Recorded values match the expected values if and only if:
    ///
    /// - The last recorded value is the last expected value
    /// - Recorded values are in the same order as expected values
    ///
    /// However, both missing and repeated values are allowed - with the only
    /// exception of the last expected value which can not be missed.
    ///
    /// For example, if the expected values are [0, 1], then the following
    /// recorded values match:
    ///
    /// - `[0, 1]` (identical values)
    /// - `[1]` (missing value but the last one)
    /// - `[0, 0, 1, 1]` (repeated value)
    ///
    /// However the following recorded values don't match, and fail the test:
    ///
    /// - `[1, 0]` (wrong order)
    /// - `[0]` (missing last value)
    /// - `[]` (missing last value)
    /// - `[0, 1, 2]` (unexpected value)
    /// - `[1, 0, 1]` (unexpected value)
    func assertValueObservationRecordingMatch<Value>(
        recorded recordedValues: [Value],
        expected expectedValues: [Value],
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line)
        where Value: Equatable
    {
        _assertValueObservationRecordingMatch(
            recorded: recordedValues,
            expected: expectedValues,
            // Last value can't be missed
            allowMissingLastValue: false,
            message(), file: file, line: line)
    }
    
    private func _assertValueObservationRecordingMatch<R, E>(
        recorded recordedValues: R,
        expected expectedValues: E,
        allowMissingLastValue: Bool,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #file,
        line: UInt = #line)
        where
        R: BidirectionalCollection,
        E: BidirectionalCollection,
        R.Element == E.Element,
        R.Element: Equatable
    {
        guard let value = expectedValues.last else {
            if !recordedValues.isEmpty {
                XCTFail("unexpected recorded prefix \(Array(recordedValues)) - \(message())", file: file, line: line)
            }
            return
        }
        
        let recordedSuffix = recordedValues.reversed().prefix(while: { $0 == value })
        let expectedSuffix = expectedValues.reversed().prefix(while: { $0 == value })
        if !allowMissingLastValue {
            // Both missing and repeated values are allowed in the recorded values.
            // This is because of asynchronous DatabasePool observations.
            if recordedSuffix.isEmpty {
                XCTFail("missing expected value \(value) - \(message())", file: file, line: line)
            }
        }
        
        let remainingRecordedValues = recordedValues.prefix(recordedValues.count - recordedSuffix.count)
        let remainingExpectedValues = expectedValues.prefix(expectedValues.count - expectedSuffix.count)
        _assertValueObservationRecordingMatch(
            recorded: remainingRecordedValues,
            expected: remainingExpectedValues,
            // Other values can be missed
            allowMissingLastValue: true,
            message(), file: file, line: line)
    }
}
