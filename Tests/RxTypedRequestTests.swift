import XCTest
import GRDB
import RxSwift
@testable import RxGRDB

class RxTypedRequestTests: RxGRDBTestCase { }

extension RxTypedRequestTests {
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

extension RxTypedRequestTests {
    func testRxFetchAllRecords() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllRecords)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllRecords)
    }
    
    func testRxFetchAllRecords(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.name }, names)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchAllRecordsDistinctUntilChanged() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllRecordsDistinctUntilChanged)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllRecordsDistinctUntilChanged)
    }
    
    func testRxFetchAllRecordsDistinctUntilChanged(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.name }, names)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchOneRecord() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneRecord)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneRecord)
    }
    
    func testRxFetchOneRecord(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.name, name)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchOneRecordDistinctUntilChanged() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneRecordDistinctUntilChanged)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneRecordDistinctUntilChanged)
    }
    
    func testRxFetchOneRecordDistinctUntilChanged(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.name, name)
        }
    }
}

// MARK: - Row

extension RxTypedRequestTests {
    func testRxFetchAllRows() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllRows)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllRows)
    }
    
    func testRxFetchAllRows(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.value(named: "name") as String }, names)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchAllRowsDistinctUntilChanged() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllRowsDistinctUntilChanged)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllRowsDistinctUntilChanged)
    }
    
    func testRxFetchAllRowsDistinctUntilChanged(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!.map { $0.value(named: "name") as String }, names)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchOneRow() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneRow)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneRow)
    }
    
    func testRxFetchOneRow(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.value(named: "name") as String?, name)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchOneRowDistinctUntilChanged() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneRowDistinctUntilChanged)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneRowDistinctUntilChanged)
    }
    
    func testRxFetchOneRowDistinctUntilChanged(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!?.value(named: "name") as String?, name)
        }
    }
}

// MARK: - DatabaseValue

extension RxTypedRequestTests {
    func testRxFetchAllDatabaseValues() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllDatabaseValues)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllDatabaseValues)
    }
    
    func testRxFetchAllDatabaseValues(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, names)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchAllDatabaseValuesDistinctUntilChanged() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllDatabaseValuesDistinctUntilChanged)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllDatabaseValuesDistinctUntilChanged)
    }
    
    func testRxFetchAllDatabaseValuesDistinctUntilChanged(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, names)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchOneDatabaseValue() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneDatabaseValue)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneDatabaseValue)
    }
    
    func testRxFetchOneDatabaseValue(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, name)
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchOneDatabaseValueDistinctUntilChanged() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchOneDatabaseValueDistinctUntilChanged)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchOneDatabaseValueDistinctUntilChanged)
    }
    
    func testRxFetchOneDatabaseValueDistinctUntilChanged(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, name) in zip(recorder.recordedEvents, expectedNames) {
            XCTAssertEqual(event.element!, name)
        }
    }
}

// MARK: - Optional DatabaseValue

extension RxTypedRequestTests {
    func testRxFetchAllOptionalDatabaseValues() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllOptionalDatabaseValues)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllOptionalDatabaseValues)
    }
    
    func testRxFetchAllOptionalDatabaseValues(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
        for (event, names) in zip(recorder.recordedEvents, expectedNames) {
            let fetchedNames = event.element!
            XCTAssertEqual(fetchedNames.count, names.count)
            for (fetchedName, name) in zip(fetchedNames, names) {
                XCTAssertEqual(fetchedName, name)
            }
        }
    }
}

extension RxTypedRequestTests {
    func testRxFetchAllOptionalDatabaseValuesDistinctUntilChanged() throws {
        try TestDatabase({ try DatabaseQueue(path: $0) }).test(with: testRxFetchAllOptionalDatabaseValuesDistinctUntilChanged)
        try TestDatabase({ try DatabasePool(path: $0) }).test(with: testRxFetchAllOptionalDatabaseValuesDistinctUntilChanged)
    }
    
    func testRxFetchAllOptionalDatabaseValuesDistinctUntilChanged(writer: DatabaseWriter) throws {
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
        
        XCTAssertEqual(recorder.recordedEvents.count, expectedNames.count)
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
