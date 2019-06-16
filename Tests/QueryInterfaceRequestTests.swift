import XCTest
import GRDB
import RxSwift
@testable import RxGRDB // @testable to get PrimaryKeyDiff initializer

private struct Parent: TableRecord, FetchableRecord, Decodable, Equatable {
    static let children = hasMany(Child.self)
    var id: Int64
    var name: String
}

private struct Child: TableRecord, FetchableRecord, Decodable, Equatable {
    var id: Int64
    var parentId: Int64
    var name: String
}

private struct ParentInfo: FetchableRecord, Decodable, Equatable {
    var parent: Parent
    var children: [Child]
}

class QueryInterfaceRequestTests : XCTestCase { }

extension QueryInterfaceRequestTests {
    func setUpDatabase(in writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId", .integer).references("parent", onDelete: .cascade)
                t.column("name", .text)
            }
            try db.execute(sql: """
                INSERT INTO parent (id, name) VALUES (1, 'foo');
                INSERT INTO parent (id, name) VALUES (2, 'bar');
                INSERT INTO child (id, parentId, name) VALUES (1, 1, 'fooA');
                INSERT INTO child (id, parentId, name) VALUES (2, 1, 'fooB');
                INSERT INTO child (id, parentId, name) VALUES (3, 2, 'barA');
                """)
        }
    }
    
    func modifyDatabase(in writer: DatabaseWriter) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM child")
        }
    }
}

// MARK: - RowConvertible

extension QueryInterfaceRequestTests {
    func testRxFetchAllRecords() throws {
        try Test(testRxFetchAllRecords)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRecords(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        let expectedRecordArrays = [
            [
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                    ]),
                ParentInfo(
                    parent: Parent(id: 2, name: "bar"),
                    children: [
                        Child(id: 3, parentId: 2, name: "barA"),
                    ]),
            ],
            [
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: []),
                ParentInfo(
                    parent: Parent(id: 2, name: "bar"),
                    children: []),
            ],
        ]
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[ParentInfo]>(expectedEventCount: expectedRecordArrays.count)
        request.rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, expectedRecords) in zip(recorder.recordedEvents, expectedRecordArrays) {
            XCTAssertEqual(event.element, expectedRecords)
        }
    }
}

extension QueryInterfaceRequestTests {
    func testRxFetchOneRecord() throws {
        try Test(testRxFetchOneRecord)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRecord(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        let expectedRecords = [
            ParentInfo(
                parent: Parent(id: 1, name: "foo"),
                children: [
                    Child(id: 1, parentId: 1, name: "fooA"),
                    Child(id: 2, parentId: 1, name: "fooB"),
                ]),
            ParentInfo(
                parent: Parent(id: 1, name: "foo"),
                children: []),
        ]

        try setUpDatabase(in: writer)
        let recorder = EventRecorder<ParentInfo?>(expectedEventCount: expectedRecords.count)
        request.rx.observeFirst(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        for (event, expectedRecord) in zip(recorder.recordedEvents, expectedRecords) {
            XCTAssertEqual(event.element, expectedRecord)
        }
    }
}

// MARK: - Row

extension QueryInterfaceRequestTests {
    func testRxFetchAllRows() throws {
        try Test(testRxFetchAllRows)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRows(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<[Row]>(expectedEventCount: 2)
        request.rx.observeAll(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        XCTAssertEqual(recorder.recordedEvents.count, 2)
        let rows = recorder.recordedEvents.map { $0.element! }
        
        XCTAssertEqual(rows[0].count, 2)
        XCTAssertEqual(rows[0][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(rows[0][0].prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        XCTAssertEqual(rows[0][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(rows[0][1].prefetchedRows["children"], [
            ["id": 3, "parentId": 2, "name": "barA", "grdb_parentId": 2]])
        
        XCTAssertEqual(rows[1].count, 2)
        XCTAssertEqual(rows[1][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(rows[1][0].prefetchedRows["children"], [])
        XCTAssertEqual(rows[1][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(rows[1][1].prefetchedRows["children"], [])
    }
}

extension QueryInterfaceRequestTests {
    func testRxFetchOneRow() throws {
        try Test(testRxFetchOneRow)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRow(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        
        try setUpDatabase(in: writer)
        let recorder = EventRecorder<Row?>(expectedEventCount: 2)
        request.rx.observeFirst(in: writer)
            .subscribe { event in
                // events are expected on the main thread by default
                assertMainQueue()
                recorder.on(event)
            }
            .disposed(by: disposeBag)
        try modifyDatabase(in: writer)
        wait(for: recorder, timeout: 1)
        
        XCTAssertEqual(recorder.recordedEvents.count, 2)
        let rows = recorder.recordedEvents.map { $0.element! }
        
        XCTAssertEqual(rows[0]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(rows[0]!.prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        
        XCTAssertEqual(rows[1]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(rows[1]!.prefetchedRows["children"], [])
    }
}
