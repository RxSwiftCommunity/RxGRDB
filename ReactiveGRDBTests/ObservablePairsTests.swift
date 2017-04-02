import XCTest
import RxSwift
@testable import ReactiveGRDB

class ObservablePairsTests: XCTestCase {
    
    func testPairs() {
        var events: [Event<(Int, Int)>] = []
        _ = Observable.from([1, 2, 3]).pairs().subscribe { events.append($0) }
        XCTAssert(events[0].element! == (1, 2))
        XCTAssert(events[1].element! == (2, 3))
        XCTAssert(events[2].isCompleted)
    }
}
