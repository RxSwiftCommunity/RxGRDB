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

class PrimaryKeyDiffScannerTests : XCTestCase {
    
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
