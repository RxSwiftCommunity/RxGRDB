#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// A type-erased DatabaseWriter
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
