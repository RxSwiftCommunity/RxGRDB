#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif

extension DatabaseWriter {
    
    /// This method is not part of GRDB because a reentrant GRDB fosters bad
    /// application patterns.
    func reentrantWrite<T>(_ block: (Database) throws -> T) rethrows -> T {
        if let db = availableDatabaseConnection {
            return try block(db)
        } else {
            return try write(block)
        }
    }
}
