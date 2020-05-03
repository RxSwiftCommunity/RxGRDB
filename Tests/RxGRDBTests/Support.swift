import XCTest
import RxSwift
import GRDB

final class Test<Context> {
    // Raise the repeatCount in order to help spotting flaky tests.
    private let repeatCount = 1
    private let test: (Context) throws -> ()
    
    init(_ test: @escaping (Context) throws -> ()) {
        self.test = test
    }
    
    @discardableResult
    func run(context: () throws -> Context) throws -> Self {
        for _ in 1...repeatCount {
            try test(context())
        }
        return self
    }
    
    @discardableResult
    func runInTemporaryDirectory(context: (_ directoryURL: URL) throws -> Context) throws -> Self {
        for _ in 1...repeatCount {
            let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("GRDBCombine", isDirectory: true)
                .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
            
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            defer {
                try! FileManager.default.removeItem(at: directoryURL)
            }
            
            try test(context(directoryURL))
        }
        return self
    }
    
    @discardableResult
    func runAtTemporaryDatabasePath(context: (_ path: String) throws -> Context) throws -> Self {
        try runInTemporaryDirectory { url in
            try context(url.appendingPathComponent("db.sqlite").path)
        }
    }
}
