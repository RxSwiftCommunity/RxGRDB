import XCTest
import GRDB
import RxSwift
@testable import RxGRDB // @testable to get PrimaryKeyDiff initializer

private struct Player: Codable, Equatable, FetchableRecord, PersistableRecord {
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

class FetchRequestObserveTests : XCTestCase { }

extension FetchRequestObserveTests {
    func setUpDatabase(in writer: DatabaseWriter) throws {
        try writer.write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            try Player(id: 2, name: "Barbara", score: nil).insert(db)
        }
    }
    
    func modifyDatabase(in writer: DatabaseWriter) throws {
        try writer.writeWithoutTransaction { db in
            try db.execute(literal: """
                UPDATE \(Player.self)
                SET \(Player.Columns.name) = \(Player.Columns.name)
                WHERE \(Player.Columns.id) = \(1);
                
                UPDATE \(Player.self)
                SET \(Player.Columns.name) = \("Barbie")
                WHERE \(Player.Columns.name) = \("Barbara");
                
                DELETE FROM \(Player.self);
                """)
            try db.inTransaction {
                try Player(id: 1, name: "Craig", score: nil).insert(db)
                try Player(id: 2, name: "David", score: 100).insert(db)
                try Player(id: 3, name: "Elena", score: 200).insert(db)
                return .commit
            }
        }
    }
}

// MARK: - Count

extension FetchRequestObserveTests {
    func testRxObserveCount() throws {
        try Test(testRxObserveCount)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveCount(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<Int>.createUnbounded()
        let request = Player.all()
        request.rx
            .observeCount(in: writer as DatabaseReader)
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(3)
                .toBlocking(timeout: 1)
                .toArray(),
            [2, 0, 3])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveCountRetry() throws {
        try Test(testRxObserveCountRetry)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveCountRetry(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.write { db in
            try Player.createTable(db)
        }
        
        // Expectation for later transaction
        let expectation = self.expectation(description: "1")
        expectation.expectedFulfillmentCount = 2    // two because subscription receives an immediate event, then a second one on retry.
        
        // Subscribe to a request
        let request = Player.all()
        var eventsCount = 0
        var needsThrow = false
        request.rx
            .observeCount(in: writer)
            .map { db in
                if needsThrow {
                    needsThrow = false
                    throw NSError(domain: "RxGRDB", code: 0)
                }
            }
            .retry()
            .subscribe(onNext: {
                eventsCount += 1
                expectation.fulfill()
            })
            .disposed(by: disposeBag)
        
        XCTAssertEqual(eventsCount, 1)
        
        needsThrow = true
        try writer.write { try Player(id: 1, name: "Arthur", score: nil).insert($0) }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(eventsCount, 2)
    }
}

// MARK: - FetchableRecord

extension FetchRequestObserveTests {
    func testRxObserveAllRecords() throws {
        try Test(testRxObserveAllRecords)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRecords(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)

        let testSubject = ReplaySubject<[String]>.createUnbounded()
        let request = Player.order(Player.Columns.name)
        request.rx
            .observeAll(in: writer)
            .map { $0.map { $0.name } }
            .subscribe(testSubject)
            .disposed(by: disposeBag)

        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(4)
                .toBlocking(timeout: 1)
                .toArray(),
            [
                ["Arthur", "Barbara"],
                ["Arthur", "Barbie"],
                [],
                ["Craig", "David", "Elena"],
            ])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveAllRecordsIdentifiedByIds() throws {
        try Test(testRxObserveAllRecordsIdentifiedByIds)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRecordsIdentifiedByIds(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<[String]>.createUnbounded()
        let request = Player.filter(keys: [2, 3]).order(Player.Columns.name)
        request.rx
            .observeAll(in: writer)
            .map { $0.map { $0.name } }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(4)
                .toBlocking(timeout: 1)
                .toArray(),
            [
                ["Barbara"],
                ["Barbie"],
                [],
                ["David", "Elena"],
            ])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveFirstRecord() throws {
        try Test(testRxObserveFirstRecord)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveFirstRecord(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<String?>.createUnbounded()
        let request = Player.order(Player.Columns.name)
        request.rx
            .observeFirst(in: writer)
            .map { $0?.name }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(3)
                .toBlocking(timeout: 1)
                .toArray(),
            ["Arthur", nil, "Craig"])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveFirstRecordIdentifiedById() throws {
        try Test(testRxObserveFirstRecordIdentifiedById)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveFirstRecordIdentifiedById(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<String?>.createUnbounded()
        let request = Player.filter(key: 2)
        request.rx
            .observeFirst(in: writer)
            .map { $0?.name }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(4)
                .toBlocking(timeout: 1)
                .toArray(),
            ["Barbara", "Barbie", nil, "David"])
    }
}

// MARK: - Row

extension FetchRequestObserveTests {
    func testRxObserveAllRows() throws {
        try Test(testRxObserveAllRows)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRows(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<[String]>.createUnbounded()
        let request: SQLRequest<Row> = "SELECT * FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        request.rx
            .observeAll(in: writer)
            .map { $0.map { $0[Player.Columns.name] as String } }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(4)
                .toBlocking(timeout: 1)
                .toArray(),
            [
                ["Arthur", "Barbara"],
                ["Arthur", "Barbie"],
                [],
                ["Craig", "David", "Elena"],
            ])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveAllRowsIdentifiedByIds() throws {
        try Test(testRxObserveAllRowsIdentifiedByIds)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRowsIdentifiedByIds(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<[String]>.createUnbounded()
        let request = Player.filter(keys: [2, 3]).order(Player.Columns.name).asRequest(of: Row.self)
        request.rx
            .observeAll(in: writer)
            .map { $0.map { $0[Player.Columns.name] as String } }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(4)
                .toBlocking(timeout: 1)
                .toArray(),
            [
                ["Barbara"],
                ["Barbie"],
                [],
                ["David", "Elena"],
            ])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveFirstRow() throws {
        try Test(testRxObserveFirstRow)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveFirstRow(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<String?>.createUnbounded()
        let request: SQLRequest<Row> = "SELECT * FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        request.rx
            .observeFirst(in: writer)
            .map { $0.map { $0[Player.Columns.name] as String } }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(3)
                .toBlocking(timeout: 1)
                .toArray(),
            ["Arthur", nil, "Craig"])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveFirstRowIdentifiedById() throws {
        try Test(testRxObserveFirstRowIdentifiedById)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveFirstRowIdentifiedById(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<String?>.createUnbounded()
        let request = Player.filter(key: 2).asRequest(of: Row.self).asRequest(of: Row.self)
        request.rx
            .observeFirst(in: writer)
            .map { $0.map { $0[Player.Columns.name] as String } }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(4)
                .toBlocking(timeout: 1)
                .toArray(),
            ["Barbara", "Barbie", nil, "David"])
    }
}

// MARK: - DatabaseValue

extension FetchRequestObserveTests {
    func testRxObserveAllDatabaseValues() throws {
        try Test(testRxObserveAllDatabaseValues)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<[String]>.createUnbounded()
        let request: SQLRequest<String> = "SELECT \(Player.Columns.name) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        request.rx
            .observeAll(in: writer)
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(4)
                .toBlocking(timeout: 1)
                .toArray(),
            [
                ["Arthur", "Barbara"],
                ["Arthur", "Barbie"],
                [],
                ["Craig", "David", "Elena"],
            ])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveFirstDatabaseValue() throws {
        try Test(testRxObserveFirstDatabaseValue)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveFirstDatabaseValue(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<String?>.createUnbounded()
        let request: SQLRequest<String> = "SELECT \(Player.Columns.name) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        request.rx
            .observeFirst(in: writer)
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(3)
                .toBlocking(timeout: 1)
                .toArray(),
            ["Arthur", nil, "Craig"])
    }
}

// MARK: - Optional DatabaseValue

extension FetchRequestObserveTests {
    func testRxObserveAllOptionalDatabaseValues() throws {
        try Test(testRxObserveAllOptionalDatabaseValues)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllOptionalDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<[Int?]>.createUnbounded()
        let request: SQLRequest<Int?> = "SELECT \(Player.Columns.score) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        request.rx
            .observeAll(in: writer)
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(3)
                .toBlocking(timeout: 1)
                .toArray(),
            [
                [1000, nil],
                [],
                [nil, 100, 200],
            ])
    }
}

extension FetchRequestObserveTests {
    func testRxObserveFirstOptionalDatabaseValues() throws {
        try Test(testRxObserveFirstOptionalDatabaseValues)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testRxObserveFirstOptionalDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let testSubject = ReplaySubject<Int?>.createUnbounded()
        let request: SQLRequest<Int?> = "SELECT \(Player.Columns.score) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        request.rx
            .observeFirst(in: writer)
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        try modifyDatabase(in: writer)
        
        try XCTAssertEqual(
            testSubject
                .take(2)
                .toBlocking(timeout: 1)
                .toArray(),
            [1000, nil])
    }
}

// MARK: - PrimaryKeyDiff

extension FetchRequestObserveTests {
    func testPrimaryKeyDiffScanner() throws {
        try Test(testPrimaryKeyDiffScanner)
            .run { DatabaseQueue() }
            .runAtPath { try DatabaseQueue(path: $0) }
            .runAtPath { try DatabasePool(path: $0) }
    }
    
    func testPrimaryKeyDiffScanner(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request = Player.orderByPrimaryKey()
        let diffScanner = try writer.read { db in
            try PrimaryKeyDiffScanner(
                database: db,
                request: request,
                initialRecords: [])
        }
        let testSubject = ReplaySubject<PrimaryKeyDiff<Player>>.createUnbounded()
        request.asRequest(of: Row.self)
            .rx
            .observeAll(in: writer)
            .scan(diffScanner) { (diffScanner, rows) in diffScanner.diffed(from: rows) }
            .map { $0.diff }
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        
        let diffs = try testSubject.take(4).toBlocking().toArray()
        XCTAssertEqual(diffs, [
            PrimaryKeyDiff(
                inserted: [
                    Player(id: 1, name: "Arthur", score: 1000),
                    Player(id: 2, name: "Barbara", score: nil),
                ],
                updated: [],
                deleted: []),
            PrimaryKeyDiff(
                inserted: [],
                updated: [Player(id: 2, name: "Barbie", score: nil)],
                deleted: []),
            PrimaryKeyDiff(
                inserted: [],
                updated: [],
                deleted: [
                    Player(id: 1, name: "Arthur", score: 1000),
                    Player(id: 2, name: "Barbie", score: nil)]),
            PrimaryKeyDiff(
                inserted: [
                    Player(id: 1, name: "Craig", score: nil),
                    Player(id: 2, name: "David", score: 100),
                    Player(id: 3, name: "Elena", score: 200),
                ],
                updated: [],
                deleted: []),
            ])
    }
}
