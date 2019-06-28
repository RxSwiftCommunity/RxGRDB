import GRDB
import RxBlocking
import RxSwift
import XCTest

class PlayersTests: XCTestCase {
    
    func testPopulateIfEmptyFromEmptyDatabase() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        let players = Players(database: dbQueue)
        
        try XCTAssertEqual(dbQueue.read(Player.fetchCount), 0)
        try XCTAssertTrue(players.populateIfEmpty())
        try XCTAssertGreaterThan(dbQueue.read(Player.fetchCount), 0)
    }
    
    func testPopulateIfEmptyFromNonEmptyDatabase() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        let players = Players(database: dbQueue)
        
        var player = Player(id: 1, name: "Arthur", score: 100)
        try dbQueue.write { db in
            try player.insert(db)
        }
        
        try XCTAssertFalse(players.populateIfEmpty())
        try XCTAssertEqual(dbQueue.read(Player.fetchAll), [player])
    }
    
    func testDeleteAll() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        let players = Players(database: dbQueue)
        
        try dbQueue.write { db in
            var player = Player(id: 1, name: "Arthur", score: 100)
            try player.insert(db)
        }
        
        try XCTAssert(players.deleteAll().toBlocking().toArray().isEmpty)
        try XCTAssertEqual(dbQueue.read(Player.fetchCount), 0)
    }
    
    func testDeleteOne() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        let players = Players(database: dbQueue)
        
        var player1 = Player(id: 1, name: "Arthur", score: 100)
        var player2 = Player(id: 2, name: "Barbara", score: 200)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        
        try XCTAssert(players.deleteOne(player1).toBlocking().toArray().isEmpty)
        try XCTAssertEqual(dbQueue.read(Player.fetchAll), [player2])
    }
    
    func testRefreshPopulatesEmptyDatabase() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        let players = Players(database: dbQueue)
        
        try XCTAssertEqual(dbQueue.read(Player.fetchCount), 0)
        try XCTAssert(players.refresh().toBlocking().toArray().isEmpty)
        try XCTAssertGreaterThan(dbQueue.read(Player.fetchCount), 0)
    }
    
    func testObserveAll() throws {
        let dbQueue = DatabaseQueue()
        try AppDatabase().setup(dbQueue)
        let players = Players(database: dbQueue)
        
        let disposeBag = DisposeBag()
        let testSubject = ReplaySubject<[Player]>.createUnbounded()
        players
            .observeAll(Player.orderByPrimaryKey())
            .subscribe(testSubject)
            .disposed(by: disposeBag)

        var player1 = Player(id: 1, name: "Arthur", score: 100)
        var player2 = Player(id: 2, name: "Barbara", score: 200)
        var player3 = Player(id: 3, name: "Craig", score: 300)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        try dbQueue.write { db in
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
