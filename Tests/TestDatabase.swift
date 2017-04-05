import Foundation
import GRDB

class TestDatabase<Writer: DatabaseWriter> {
    private let directoryURL: URL
    private var writer: Writer!
    
    init(_ writer: (String) throws -> Writer) throws {
        directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        self.writer = try writer(directoryURL.appendingPathComponent("db.sqlite").path)
    }
    
    @discardableResult
    func test(with testClosure: (Writer) throws -> ()) rethrows -> Self {
        try testClosure(writer)
        return self
    }
    
    deinit {
        self.writer = nil
        try! FileManager.default.removeItem(at: directoryURL)
    }
}

