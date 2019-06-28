import GRDB
import RxBlocking
import RxSwift
import XCTest

class PlayersTests: XCTestCase {
    
    private func makeDatabase() throws -> DatabaseQueue {
        // Players needs a database.
        // Setup an in-memory database, for fast access.
        let database = DatabaseQueue()
        try AppDatabase().setup(database)
        return database
    }
    
    func testPopulateIfEmptyFromEmptyDatabase() throws {
        let database = try makeDatabase()
        let players = Players(database: database)
        
        try XCTAssertEqual(database.read(Player.fetchCount), 0)
        try XCTAssertTrue(players.populateIfEmpty())
        try XCTAssertGreaterThan(database.read(Player.fetchCount), 0)
    }
    
    func testPopulateIfEmptyFromNonEmptyDatabase() throws {
        let database = try makeDatabase()
        let players = Players(database: database)
        
        var player = Player(id: 1, name: "Arthur", score: 100)
        try database.write { db in
            try player.insert(db)
        }
        
        try XCTAssertFalse(players.populateIfEmpty())
        try XCTAssertEqual(database.read(Player.fetchAll), [player])
    }
    
    func testDeleteAll() throws {
        let database = try makeDatabase()
        let players = Players(database: database)
        
        try database.write { db in
            var player = Player(id: 1, name: "Arthur", score: 100)
            try player.insert(db)
        }
        
        _ = players.deleteAll().toBlocking().materialize()
        try XCTAssertEqual(database.read(Player.fetchCount), 0)
    }
    
    func testDeleteOne() throws {
        let database = try makeDatabase()
        let players = Players(database: database)
        
        var player1 = Player(id: 1, name: "Arthur", score: 100)
        var player2 = Player(id: 2, name: "Barbara", score: 200)
        try database.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        
        _ = players.deleteOne(player1).toBlocking().materialize()
        try XCTAssertEqual(database.read(Player.fetchAll), [player2])
    }
    
    func testRefreshPopulatesEmptyDatabase() throws {
        let database = try makeDatabase()
        let players = Players(database: database)
        
        try XCTAssertEqual(database.read(Player.fetchCount), 0)
        _ = players.refresh().toBlocking().materialize()
        try XCTAssertGreaterThan(database.read(Player.fetchCount), 0)
    }
    
    func testObserveAll() throws {
        let database = try makeDatabase()
        let players = Players(database: database)
        
        let disposeBag = DisposeBag()
        let testSubject = ReplaySubject<[Player]>.createUnbounded()
        players
            .observeAll(Player.orderByPrimaryKey())
            .subscribe(testSubject)
            .disposed(by: disposeBag)
        
        var player1 = Player(id: 1, name: "Arthur", score: 100)
        var player2 = Player(id: 2, name: "Barbara", score: 200)
        var player3 = Player(id: 3, name: "Craig", score: 300)
        try database.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        try database.write { db in
            try player2.delete(db)
            try player3.insert(db)
        }
        
        let expectedElements: [[Player]] = [
            [],
            [player1, player2],
            [player1, player3],
        ]
        try XCTAssertEqual(
            testSubject
                .take(expectedElements.count)
                .toBlocking()
                .toArray(),
            expectedElements)
    }
}
