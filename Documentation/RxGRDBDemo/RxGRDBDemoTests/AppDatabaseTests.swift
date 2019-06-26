import XCTest
import GRDB

class AppDatabaseTests: XCTestCase {
    
    func testDatabaseSchemaContainsPlayerTable() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        try dbQueue.read { db in
            try XCTAssert(db.tableExists(Player.databaseTableName))
        }
    }
    
    func testCanInsertPlayer() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        try dbQueue.write { db in
            var player = Player(id: nil, name: "Arthur", score: 100)
            try player.insert(db)
            XCTAssertNotNil(player.id)
        }
    }
    
    func testPlayerRoundtrip() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        try dbQueue.write { db in
            var insertedPlayer = Player(id: 1, name: "Arthur", score: 100)
            try insertedPlayer.insert(db)
            let fetchedPlayer = try Player.fetchOne(db, key: 1)
            XCTAssertEqual(insertedPlayer, fetchedPlayer)
        }
    }
}
