import XCTest
import GRDB

class PlayerTests: XCTestCase {
    
    func testInsert() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        try dbQueue.write { db in
            var player = Player(id: nil, name: "Arthur", score: 100)
            try player.insert(db)
            XCTAssertNotNil(player.id)
        }
    }
    
    func testRoundtrip() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        try dbQueue.write { db in
            var insertedPlayer = Player(id: 1, name: "Arthur", score: 100)
            try insertedPlayer.insert(db)
            let fetchedPlayer = try Player.fetchOne(db, key: 1)
            XCTAssertEqual(insertedPlayer, fetchedPlayer)
        }
    }
    
    func testOrderByScore() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        
        var player1 = Player(id: 1, name: "Arthur", score: 100)
        var player2 = Player(id: 2, name: "Barbara", score: 200)
        var player3 = Player(id: 3, name: "Craig", score: 150)
        var player4 = Player(id: 4, name: "David", score: 150)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
            try player3.insert(db)
            try player4.insert(db)
        }
        
        try XCTAssertEqual(
            dbQueue.read(Player.all().orderByScore().fetchAll),
            [player2, player3, player4, player1])
        
        try dbQueue.write { db in
            _ = try player1.updateChanges(db) { $0.score = 300 }
        }
        
        try XCTAssertEqual(
            dbQueue.read(Player.all().orderByScore().fetchAll),
            [player1, player2, player3, player4])
    }
    
    func testOrderByName() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        
        var player1 = Player(id: 1, name: "Arthur", score: 100)
        var player2 = Player(id: 2, name: "Barbara", score: 200)
        var player3 = Player(id: 3, name: "Craig", score: 150)
        var player4 = Player(id: 4, name: "David", score: 150)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
            try player3.insert(db)
            try player4.insert(db)
        }
        
        try XCTAssertEqual(
            dbQueue.read(Player.all().orderByName().fetchAll),
            [player1, player2, player3, player4])
        
        try dbQueue.write { db in
            _ = try player1.updateChanges(db) { $0.name = "Craig" }
        }
        
        try XCTAssertEqual(
            dbQueue.read(Player.all().orderByName().fetchAll),
            [player2, player3, player1, player4])
    }
}
