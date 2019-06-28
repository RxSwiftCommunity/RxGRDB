import XCTest
import GRDB

class AppDatabaseTests: XCTestCase {
    
    func testDatabaseSchemaContainsPlayerTable() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        try dbQueue.read { db in
            try XCTAssert(db.tableExists("player"))
            let columns = try db.columns(in: "player")
            let columnNames = Set(columns.map { $0.name })
            XCTAssertEqual(columnNames, ["id", "name", "score"])
        }
    }
}
