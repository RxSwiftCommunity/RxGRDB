import XCTest
import RxSwift
import GRDB

final class Test<Context> {
    private let test: (Context, DisposeBag) throws -> ()
    
    init(_ test: @escaping (Context, DisposeBag) throws -> ()) {
        self.test = test
    }
    
    @discardableResult
    func run(_ makeContext: () throws -> Context) throws -> Self {
        try executeTest(makeContext())
        return self
    }
    
    @discardableResult
    func runAtPath(_ makeContext: (_ path: String) throws -> Context) throws -> Self {
        // Create temp directory
        let fm = FileManager.default
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RxGRDBTests", isDirectory: true)
            .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        
        do {
            // Run test inside temp directory
            let databasePath = directoryURL.appendingPathComponent("db.sqlite").path
            let context = try makeContext(databasePath)
            try executeTest(context)
        }
        
        // Destroy temp directory
        try! FileManager.default.removeItem(at: directoryURL)
        return self
    }
    
    private func executeTest(_ context: Context) throws {
        let bag = DisposeBag()
        try test(context, bag)
    }
}
