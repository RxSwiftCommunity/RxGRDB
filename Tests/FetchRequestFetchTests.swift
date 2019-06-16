import XCTest
import GRDB
import RxSwift
@testable import RxGRDB // @testable to get PrimaryKeyDiff initializer

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

class FetchRequestFetchTests : XCTestCase { }

extension FetchRequestFetchTests {
    func setUpDatabase(in writer: DatabaseWriter) throws {
        try writer.write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 1000).insert(db)
            try Player(id: 2, name: "Barbara", score: nil).insert(db)
        }
    }
}

// MARK: - Count

extension FetchRequestFetchTests {
    func testRxFetchCount() throws {
        try Test(testRxFetchCount)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchCount(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request = Player.all()
        let single = request.rx
            .fetchCount(in: writer as DatabaseReader)
        let count = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(count, 2)
    }
}

// MARK: - FetchableRecord

extension FetchRequestFetchTests {
    func testRxFetchAllRecords() throws {
        try Test(testRxFetchAllRecords)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRecords(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)

        let request = Player.order(Player.Columns.name)
        let single = request.rx
            .fetchAll(in: writer as DatabaseReader)
            .map { $0.map { $0.name } }
        let names = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(names, ["Arthur", "Barbara"])
    }
}

extension FetchRequestFetchTests {
    func testRxFetchOneRecord() throws {
        try Test(testRxFetchOneRecord)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRecord(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)

        let request = Player.order(Player.Columns.name)
        let single = request.rx
            .fetchOne(in: writer as DatabaseReader)
            .map { $0?.name }
        let name = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(name, "Arthur")
    }
}

// MARK: - Row

extension FetchRequestFetchTests {
    func testRxFetchAllRows() throws {
        try Test(testRxFetchAllRows)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllRows(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request: SQLRequest<Row> = "SELECT * FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        let single = request.rx
            .fetchAll(in: writer as DatabaseReader)
            .map { $0.map { $0[Player.Columns.name] as String } }
        let names = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(names, ["Arthur", "Barbara"])
    }
}

extension FetchRequestFetchTests {
    func testRxFetchOneRow() throws {
        try Test(testRxFetchOneRow)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneRow(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request: SQLRequest<Row> = "SELECT * FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        let single = request.rx
            .fetchOne(in: writer as DatabaseReader)
            .map { $0.map { $0[Player.Columns.name] as String } }
        let name = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(name, "Arthur")
    }
}

// MARK: - DatabaseValue

extension FetchRequestFetchTests {
    func testRxFetchAllDatabaseValues() throws {
        try Test(testRxFetchAllDatabaseValues)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request: SQLRequest<String> = "SELECT \(Player.Columns.name) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        let single = request.rx
            .fetchAll(in: writer as DatabaseReader)
        let names = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(names, ["Arthur", "Barbara"])
    }
}

extension FetchRequestFetchTests {
    func testRxFetchOneDatabaseValue() throws {
        try Test(testRxFetchOneDatabaseValue)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneDatabaseValue(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request: SQLRequest<String> = "SELECT \(Player.Columns.name) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        let single = request.rx
            .fetchOne(in: writer as DatabaseReader)
        let names = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(names, "Arthur")
    }
}

// MARK: - Optional DatabaseValue

extension FetchRequestFetchTests {
    func testRxFetchAllOptionalDatabaseValues() throws {
        try Test(testRxFetchAllOptionalDatabaseValues)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchAllOptionalDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request: SQLRequest<Int?> = "SELECT \(Player.Columns.score) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        let single = request.rx
            .fetchAll(in: writer as DatabaseReader)
        let scores = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(scores, [1000, nil])
    }
}

extension FetchRequestFetchTests {
    func testRxFetchOneOptionalDatabaseValues() throws {
        try Test(testRxFetchOneOptionalDatabaseValues)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRxFetchOneOptionalDatabaseValues(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try setUpDatabase(in: writer)
        
        let request: SQLRequest<Int?> = "SELECT \(Player.Columns.score) FROM \(Player.self) ORDER BY \(Player.Columns.name)"
        let single = request.rx
            .fetchOne(in: writer as DatabaseReader)
        let score = try single.toBlocking(timeout: 1).single()
        XCTAssertEqual(score, 1000)
    }
}
