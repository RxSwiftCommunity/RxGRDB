import Action
import GRDB
import RxBlocking
import RxSwift
import XCTest

class PlayersViewModelTests: XCTestCase {
    override func setUp() {
        // PlayerViewModel needs a Current World.
        // Setup one with an in-memory database, for fast access.
        let dbQueue = try! DatabaseQueue()
        try! AppDatabase().setup(dbQueue)
        Current = World(database: { dbQueue })
    }
    
    func testInitialStateFromEmptyDatabase() throws {
        let viewModel = PlayersViewModel()
        let orderingButtonTitle = try viewModel.orderingButtonTitle.take(1).toBlocking().single()
        let players = try viewModel.players.take(1).toBlocking().single()
        XCTAssertNil(orderingButtonTitle)
        XCTAssert(players.isEmpty)
    }
    
    func testInitialStateFromNonEmptyDatabase() throws {
        try Current.players().populateIfEmpty()
        let viewModel = PlayersViewModel()
        let orderingButtonTitle = try viewModel.orderingButtonTitle.take(1).toBlocking().single()
        let players = try viewModel.players.take(1).toBlocking().single()
        XCTAssertEqual(orderingButtonTitle, "Score ⬇︎")
        XCTAssert(!players.isEmpty)
    }
    
    func testToggleOrdering() throws {
        try Current.players().populateIfEmpty()
        let viewModel = PlayersViewModel()
        _ = viewModel.toggleOrdering.execute().toBlocking().materialize()
        let orderingButtonTitle = try viewModel.orderingButtonTitle.take(1).toBlocking().single()
        XCTAssertEqual(orderingButtonTitle, "Name ⬆︎")
    }
}
