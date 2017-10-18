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

class AnyDatabaseWriter : DatabaseWriter, ReactiveCompatible {
    let base: DatabaseWriter
    
    init(_ base: DatabaseWriter) {
        self.base = base
    }
    
    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.read(block)
    }
    
    func unsafeRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.unsafeRead(block)
    }
    
    func unsafeReentrantRead<T>(_ block: (Database) throws -> T) throws -> T {
        return try base.unsafeReentrantRead(block)
    }
    
    func add(function: DatabaseFunction) {
        base.add(function: function)
    }
    
    func remove(function: DatabaseFunction) {
        base.remove(function: function)
    }
    
    func add(collation: DatabaseCollation) {
        base.add(collation: collation)
    }
    
    func remove(collation: DatabaseCollation) {
        base.remove(collation: collation)
    }
    
    func write<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try base.write(block)
    }
    
    func unsafeReentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T {
        return try base.unsafeReentrantWrite(block)
    }
    
    func readFromCurrentState(_ block: @escaping (Database) -> Void) throws {
        try base.readFromCurrentState(block)
    }
}
