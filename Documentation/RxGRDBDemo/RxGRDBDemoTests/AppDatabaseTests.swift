import XCTest
import GRDB

class AppDatabaseTests: XCTestCase {
    
    func testDatabaseSchemaContainsPlayerTable() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        try dbQueue.read { db in
            try XCTAssert(db.tableExists("player"))
        }
    }
}
