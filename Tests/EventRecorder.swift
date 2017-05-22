import XCTest
import RxSwift

class EventRecorder<E> : ObserverType {
    fileprivate let expectation: XCTestExpectation
    private(set) var recordedEvents: [Event<E>] = []
    
    init(expectedEventCount: Int, description: String = "") {
        expectation = XCTestExpectation(description: description)
        expectation.expectedFulfillmentCount = UInt(expectedEventCount)
    }
    
    func on(_ event: Event<E>) {
        recordedEvents.append(event)
        expectation.fulfill()
    }
}

extension XCTestCase {
    func wait<E>(for recorder: EventRecorder<E>, timeout seconds: TimeInterval) {
        wait(for: [recorder.expectation], timeout: seconds)
    }
}

