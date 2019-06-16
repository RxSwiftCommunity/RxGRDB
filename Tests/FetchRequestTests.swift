import XCTest
import GRDB
import RxSwift
@testable import RxGRDB // @testable to get PrimaryKeyDiff initializer

// The tested request
private struct CustomFetchRequest<T>: FetchRequest, ReactiveCompatible {
    typealias RowDecoder = T
    
    private let _prepare: (Database, _ singleResult: Bool) throws -> (SelectStatement, RowAdapter?)
    private let _fetchCount: (Database) throws -> Int
    private let _databaseRegion: (Database) throws -> DatabaseRegion
    
    init<Request: FetchRequest>(_ request: Request) where Request.RowDecoder == T {
        _prepare = request.prepare
        _fetchCount = request.fetchCount
        _databaseRegion = request.databaseRegion
    }
    
    func prepare(_ db: Database, forSingleResult singleResult: Bool) throws -> (SelectStatement, RowAdapter?) {
        return try _prepare(db, singleResult)
    }
    
    func fetchCount(_ db: Database) throws -> Int {
        return try _fetchCount(db)
    }
    
    func databaseRegion(_ db: Database) throws -> DatabaseRegion {
        return try _databaseRegion(db)
    }
}

class FetchRequestTests : XCTestCase { }

extension FetchRequestTests {
    func setUpDatabase(in writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "player") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
                t.column("email", .text)
            }
            var player = Player(id: nil, name: "Arthur", email: "arthur@example.com")
            try player.insert(db)
            player = Player(id: nil, name: "Barbara", email: nil)
            try player.insert(db)
        }
    }
    
    func modifyDatabase(in writer: DatabaseWriter) throws {
        try writer.writeWithoutTransaction { db in
            try db.execute(sql: "UPDATE player SET name = name WHERE id = 1")
            try db.execute(sql: "UPDATE player SET name = ? WHERE name = ?", arguments: ["Barbie", "Barbara"])
            _ = try Player.deleteAll(db)
            try db.inTransaction {
                var player = Player(id: nil, name: "Craig", email: nil)
                try player.insert(db)
                player = Player(id: nil, name: "David", email: "david@example.com")
                try player.insert(db)
                player = Player(id: nil, name: "Elena", email: "elena@example.com")
                try player.insert(db)
                return .commit
            }
        }
    }
}

// MARK: - RowConvertible

extension FetchRequestTests {
    func testRxObserveAllRecords() throws {
        try Test(testRxObserveAllRecords)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRecords(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Player.order(Column("name"))
        let expectedNames = [
            ["Arthur", "Barbara"],
            ["Arthur", "Barbie"],
            [],
            ["Craig", "David", "Elena"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Player]>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.name }, names)
        }
    }
}

extension FetchRequestTests {
    func testRxObserveAllRecordsIdentifiedByIds() throws {
        try Test(testRxObserveAllRecordsIdentifiedByIds)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRecordsIdentifiedByIds(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Player.filter(keys: [2, 3]).order(Column("name"))
        let expectedNames = [
            ["Barbara"],
            ["Barbie"],
            [],
            ["David", "Elena"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Player]>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.name }, names)
        }
    }
}

extension FetchRequestTests {
    func testRxObserveOneRecord() throws {
        try Test(testRxObserveOneRecord)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveOneRecord(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Player.order(Column("name"))
        let expectedNames = [
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Player?>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeFirst(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.name, name)
        }
    }
}

extension FetchRequestTests {
    func testRxObserveOneRecordIdentifiedById() throws {
        try Test(testRxObserveOneRecordIdentifiedById)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveOneRecordIdentifiedById(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Player.filter(key: 2)
        let expectedNames = [
            "Barbara",
            "Barbie",
            nil,
            "David"
        ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Player?>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeFirst(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.name, name)
        }
    }
}

// MARK: - Row

extension FetchRequestTests {
    func testRxObserveAllRows() throws {
        try Test(testRxObserveAllRows)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRows(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY name")
        let expectedNames = [
            ["Arthur", "Barbara"],
            ["Arthur", "Barbie"],
            [],
            ["Craig", "David", "Elena"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Row]>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0["name"] as String }, names)
        }
    }
}

extension FetchRequestTests {
    func testRxObserveAllRowsIdentifiedByIds() throws {
        try Test(testRxObserveAllRowsIdentifiedByIds)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllRowsIdentifiedByIds(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Player.filter(keys: [2, 3]).order(Column("name")).asRequest(of: Row.self)
        let expectedNames = [
            ["Barbara"],
            ["Barbie"],
            [],
            ["David", "Elena"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Row]>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0["name"] as String }, names)
        }
    }
}

extension FetchRequestTests {
    func testRxObserveOneRow() throws {
        try Test(testRxObserveOneRow)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveOneRow(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest<Row>(sql: "SELECT * FROM player ORDER BY name")
        let expectedNames = [
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Row?>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeFirst(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?["name"] as String?, name)
        }
    }
}

extension FetchRequestTests {
    func testRxObserveOneRowIdentifiedById() throws {
        try Test(testRxObserveOneRowIdentifiedById)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveOneRowIdentifiedById(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Player.filter(key: 2).asRequest(of: Row.self)
        let expectedNames = [
            "Barbara",
            "Barbie",
            nil,
            "David"
        ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Row?>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeFirst(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?["name"] as String?, name)
        }
    }
}

// MARK: - DatabaseValue

extension FetchRequestTests {
    func testRxObserveAllDatabaseValues() throws {
        try Test(testRxObserveAllDatabaseValues)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest<String>(sql: "SELECT name FROM player ORDER BY name")
        let expectedNames = [
            ["Arthur", "Barbara"],
            ["Arthur", "Barbie"],
            [],
            ["Craig", "David", "Elena"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[String]>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, names)
        }
    }
}

extension FetchRequestTests {
    func testRxObserveOneDatabaseValue() throws {
        try Test(testRxObserveOneDatabaseValue)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveOneDatabaseValue(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest<String>(sql: "SELECT name FROM player ORDER BY name")
        let expectedNames = [
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<String?>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeFirst(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, name)
        }
    }
}

// MARK: - Optional DatabaseValue

extension FetchRequestTests {
    func testRxObserveAllOptionalDatabaseValues() throws {
        try Test(testRxObserveAllOptionalDatabaseValues)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxObserveAllOptionalDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest<String?>(sql: "SELECT email FROM player ORDER BY name")
        let expectedNames = [
            ["arthur@example.com", nil],
            [],
            [nil, "david@example.com", "elena@example.com"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[String?]>(expectedEventCount: expectedNames.count)
        CustomFetchRequest(request).rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            let fetchedNames = event.element!
            XCTAssertEqual(fetchedNames.count, names.count)
            for (fetchedName, name) in zip(fetchedNames, names) {
                XCTAssertEqual(fetchedName, name)
            }
        }
    }
}

extension FetchRequestTests {
    func testPrimaryKeyDiffScanner() throws {
        try Test(testPrimaryKeyDiffScanner)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testPrimaryKeyDiffScanner(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Player.orderByPrimaryKey()
        let expectedDiffs = [
            PrimaryKeyDiff(
                inserted: [
                    Player(id: 1, name: "Arthur", email: "arthur@example.com"),
                    Player(id: 2, name: "Barbara", email: nil),
                    ],
                updated: [],
                deleted: []),
            PrimaryKeyDiff(
                inserted: [],
                updated: [Player(id: 2, name: "Barbie", email: nil)],
                deleted: []),
            PrimaryKeyDiff(
                inserted: [],
                updated: [],
                deleted: [
                    Player(id: 1, name: "Arthur", email: "arthur@example.com"),
                    Player(id: 2, name: "Barbie", email: nil)]),
            PrimaryKeyDiff(
                inserted: [
                    Player(id: 1, name: "Craig", email: nil),
                    Player(id: 2, name: "David", email: "david@example.com"),
                    Player(id: 3, name: "Elena", email: "elena@example.com"),
                    ],
                updated: [],
                deleted: []),
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<PrimaryKeyDiff<Player>>(expectedEventCount: expectedDiffs.count)
        
        let diffScanner = try writer.read { db in
            try PrimaryKeyDiffScanner(
                database: db,
                request: request,
                initialRecords: [])
        }
        CustomFetchRequest(request.asRequest(of: Row.self))
            .rx
            .observeAll(in: writer)
            .scan(diffScanner) { (diffScanner, rows) in diffScanner.diffed(from: rows) }
            .map { $0.diff }
            .subscribe(recorder)
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, expectedDiff) in zip(recorder.recordedEvents, expectedDiffs) {
            let diff = event.element!
            XCTAssertEqual(diff.inserted, expectedDiff.inserted)
            XCTAssertEqual(diff.updated, expectedDiff.updated)
            XCTAssertEqual(diff.deleted, expectedDiff.deleted)
        }
    }
}

// MARK: - Support

private struct Player : FetchableRecord, MutablePersistableRecord, Codable, Equatable {
    var id: Int64?
    var name: String
    var email: String?
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
