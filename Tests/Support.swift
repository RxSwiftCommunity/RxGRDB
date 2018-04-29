import XCTest
import RxSwift
import GRDB

class Test {
    let testClosure: (DatabaseWriter, DisposeBag) throws -> ()
    
    init(_ testClosure: @escaping (DatabaseWriter, DisposeBag) throws -> ()) {
        self.testClosure = testClosure
    }
    
    @discardableResult
    func run(_ writer: (_ path: String) throws -> DatabaseWriter) throws -> Self {
        // Create temp directory
        let fm = FileManager.default
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RxGRDBTests", isDirectory: true)
            .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        
        do {
            // Run test inside temp directory
            let databasePath = directoryURL.appendingPathComponent("db.sqlite").path
            let writer = try writer(databasePath)
            try testClosure(writer, DisposeBag())
        }
        
        // Destroy temp directory
        try! FileManager.default.removeItem(at: directoryURL)
        return self
    }
}

class EventRecorder<E> : ObserverType {
    fileprivate let expectation: XCTestExpectation
    private(set) var recordedEvents: [Event<E>] = []
    
    init(expectedEventCount: Int, description: String = "") {
        expectation = XCTestExpectation(description: description)
        expectation.expectedFulfillmentCount = expectedEventCount
        expectation.assertForOverFulfill = true
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


fileprivate let mainQueueKey = DispatchSpecificKey<Void>()
func assertMainQueue(_ message: @autoclosure () -> String = "Not on the main dispatch queue", file: StaticString = #file, line: UInt = #line) {
    DispatchQueue.main.setSpecific(key: mainQueueKey, value: ())
    XCTAssertNotNil(DispatchQueue.getSpecific(key: mainQueueKey), message, file: file, line: line)
}
