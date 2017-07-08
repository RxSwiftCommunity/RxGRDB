import XCTest
import GRDB
import RxSwift
import RxGRDB

class TypedRequestTests : XCTestCase { }

extension TypedRequestTests {
    func setUpDatabase(in writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "persons") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
                t.column("email", .text)
            }
            try Person(id: nil, name: "Arthur", email: "arthur@example.com").insert(db)
            try Person(id: nil, name: "Barbara", email: nil).insert(db)
        }
    }
    
    func modifyDatabase(in writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.execute("UPDATE persons SET name = name")
            _ = try Person.deleteAll(db)
            try db.inTransaction {
                try Person(id: nil, name: "Craig", email: nil).insert(db)
                try Person(id: nil, name: "David", email: "david@example.com").insert(db)
                return .commit
            }
        }
    }
}

// MARK: - RowConvertible

extension TypedRequestTests {
    func testRxFetchAllRecords() throws {
        try Test(testRxFetchAllRecords)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRecords(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Person.order(Column("name"))
        let expectedNames = [
            ["Arthur", "Barbara"],
            ["Arthur", "Barbara"],
            [],
            ["Craig", "David"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Person]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.name }, names)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchAllRecordsDistinctUntilChanged() throws {
        try Test(testRxFetchAllRecordsDistinctUntilChanged)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRecordsDistinctUntilChanged(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Person.order(Column("name"))
        let expectedNames = [
            ["Arthur", "Barbara"],
            [],
            ["Craig", "David"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Person]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer, distinctUntilChanged: true)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.name }, names)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchOneRecord() throws {
        try Test(testRxFetchOneRecord)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRecord(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Person.order(Column("name"))
        let expectedNames = [
            "Arthur",
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Person?>(expectedEventCount: expectedNames.count)
        request.rx.fetchOne(in: writer)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.name, name)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchOneRecordDistinctUntilChanged() throws {
        try Test(testRxFetchOneRecordDistinctUntilChanged)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRecordDistinctUntilChanged(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Person.order(Column("name"))
        let expectedNames = [
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Person?>(expectedEventCount: expectedNames.count)
        request.rx.fetchOne(in: writer, distinctUntilChanged: true)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.name, name)
        }
    }
}

// MARK: - Row

extension TypedRequestTests {
    func testRxFetchAllRows() throws {
        try Test(testRxFetchAllRows)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRows(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT * FROM persons ORDER BY name").asRequest(of: Row.self)
        let expectedNames = [
            ["Arthur", "Barbara"],
            ["Arthur", "Barbara"],
            [],
            ["Craig", "David"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Row]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.value(named: "name") as String }, names)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchAllRowsDistinctUntilChanged() throws {
        try Test(testRxFetchAllRowsDistinctUntilChanged)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRowsDistinctUntilChanged(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT * FROM persons ORDER BY name").asRequest(of: Row.self)
        let expectedNames = [
            ["Arthur", "Barbara"],
            [],
            ["Craig", "David"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Row]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer, distinctUntilChanged: true)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.value(named: "name") as String }, names)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchOneRow() throws {
        try Test(testRxFetchOneRow)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRow(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT * FROM persons ORDER BY name").asRequest(of: Row.self)
        let expectedNames = [
            "Arthur",
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Row?>(expectedEventCount: expectedNames.count)
        request.rx.fetchOne(in: writer)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.value(named: "name") as String?, name)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchOneRowDistinctUntilChanged() throws {
        try Test(testRxFetchOneRowDistinctUntilChanged)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRowDistinctUntilChanged(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT * FROM persons ORDER BY name").asRequest(of: Row.self)
        let expectedNames = [
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Row?>(expectedEventCount: expectedNames.count)
        request.rx.fetchOne(in: writer, distinctUntilChanged: true)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.value(named: "name") as String?, name)
        }
    }
}

// MARK: - DatabaseValue

extension TypedRequestTests {
    func testRxFetchAllDatabaseValues() throws {
        try Test(testRxFetchAllDatabaseValues)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT name FROM persons ORDER BY name").asRequest(of: String.self)
        let expectedNames = [
            ["Arthur", "Barbara"],
            ["Arthur", "Barbara"],
            [],
            ["Craig", "David"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[String]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, names)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchAllDatabaseValuesDistinctUntilChanged() throws {
        try Test(testRxFetchAllDatabaseValuesDistinctUntilChanged)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllDatabaseValuesDistinctUntilChanged(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT name FROM persons ORDER BY name").asRequest(of: String.self)
        let expectedNames = [
            ["Arthur", "Barbara"],
            [],
            ["Craig", "David"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[String]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer, distinctUntilChanged: true)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, names)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchOneDatabaseValue() throws {
        try Test(testRxFetchOneDatabaseValue)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneDatabaseValue(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT name FROM persons ORDER BY name").asRequest(of: String.self)
        let expectedNames = [
            "Arthur",
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<String?>(expectedEventCount: expectedNames.count)
        request.rx.fetchOne(in: writer)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, name)
        }
    }
}

extension TypedRequestTests {
    func testRxFetchOneDatabaseValueDistinctUntilChanged() throws {
        try Test(testRxFetchOneDatabaseValueDistinctUntilChanged)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneDatabaseValueDistinctUntilChanged(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT name FROM persons ORDER BY name").asRequest(of: String.self)
        let expectedNames = [
            "Arthur",
            nil,
            "Craig",
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<String?>(expectedEventCount: expectedNames.count)
        request.rx.fetchOne(in: writer, distinctUntilChanged: true)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, name)
        }
    }
}

// MARK: - Optional DatabaseValue

extension TypedRequestTests {
    func testRxFetchAllOptionalDatabaseValues() throws {
        try Test(testRxFetchAllOptionalDatabaseValues)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllOptionalDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT email FROM persons ORDER BY name").asRequest(of: Optional<String>.self)
        let expectedNames = [
            ["arthur@example.com", nil],
            ["arthur@example.com", nil],
            [],
            [nil, "david@example.com"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[String?]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
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

extension TypedRequestTests {
    func testRxFetchAllOptionalDatabaseValuesDistinctUntilChanged() throws {
        try Test(testRxFetchAllOptionalDatabaseValuesDistinctUntilChanged)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllOptionalDatabaseValuesDistinctUntilChanged(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = SQLRequest("SELECT email FROM persons ORDER BY name").asRequest(of: Optional<String>.self)
        let expectedNames = [
            ["arthur@example.com", nil],
            [],
            [nil, "david@example.com"],
            ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[String?]>(expectedEventCount: expectedNames.count)
        request.rx.fetchAll(in: writer, distinctUntilChanged: true)
            .subscribe { event in
                // events are expected to be delivered on the main thread
                XCTAssertTrue(Thread.isMainThread)
                recorder.on(event)
            }
            .addDisposableTo(disposeBag)
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

// MARK: - Support

private class Person: Record {
    var id: Int64?
    var name: String
    var email: String?
    
    init(id: Int64?, name: String, email: String?) {
        self.id = id
        self.name = name
        self.email = email
        super.init()
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        name = row.value(named: "name")
        email = row.value(named: "email")
        super.init(row: row)
    }
    
    override class var databaseTableName: String { return "persons" }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["email"] = email
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
