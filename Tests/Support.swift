import XCTest
import RxSwift
import GRDB

final class Test<Context> {
    let testClosure: (Context, DisposeBag) throws -> ()
    
    init(_ testClosure: @escaping (Context, DisposeBag) throws -> ()) {
        self.testClosure = testClosure
    }
    
    @discardableResult
    func run(_ context: (_ path: String) throws -> Context) throws -> Self {
        // Create temp directory
        let fm = FileManager.default
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RxGRDBTests", isDirectory: true)
            .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        
        do {
            // Run test inside temp directory
            let databasePath = directoryURL.appendingPathComponent("db.sqlite").path
            let context = try context(databasePath)
            try testClosure(context, DisposeBag())
        }
        
        // Destroy temp directory
        try! FileManager.default.removeItem(at: directoryURL)
        return self
    }
}
