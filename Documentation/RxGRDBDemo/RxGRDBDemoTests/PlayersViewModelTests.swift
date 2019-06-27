import GRDB
import RxBlocking
import RxSwift
import XCTest

class PlayersViewModelTests: XCTestCase {
    override func setUp() {
        // PlayerViewModel feeds from Current World.
        // Setup one with an in-memory databaase, for fast database access.
        let dbQueue = DatabaseQueue()
        try! AppDatabase().setup(dbQueue)
        Current = World(database: { dbQueue })
    }
    
    func testInitialStateFromEmptyDatabase() throws {
        let viewModel = PlayersViewModel()
        let orderingButtonTitle = try viewModel.orderingButtonTitle.take(1).toBlocking(timeout: 1).single()
        let players = try viewModel.players.take(1).toBlocking(timeout: 1).single()
        XCTAssertNil(orderingButtonTitle)
        XCTAssert(players.isEmpty)
    }
    
    func testInitialStateFromNonEmptyDatabase() throws {
        try Current.players().populateIfEmpty()
        let viewModel = PlayersViewModel()
        let orderingButtonTitle = try viewModel.orderingButtonTitle.take(1).toBlocking(timeout: 1).single()
        let players = try viewModel.players.take(1).toBlocking(timeout: 1).single()
        XCTAssertEqual(orderingButtonTitle, "Score ⬇︎")
        XCTAssert(!players.isEmpty)
    }
}
