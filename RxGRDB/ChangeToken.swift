#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// Change tokens let you turn notifications of database changes into
/// fetched values.
///
/// To generate change tokens, see `DatabaseWriter.rx.changeTokens(in:synchronizedStart:)`.
///
/// To turn change tokens into fetched values, see `ObservableType.mapFetch(resultQueue:_:)`.
///
///     dbQueue.rx
///         .changeTokens(in: [...]) // observe changes in some requests
///         .mapFetch { (db: Database) in
///             return ...           // fetch some values
///         }
public struct ChangeToken {
    enum Mode {
        case initialSync(Database)
        case async(DatabaseWriter, Database)
    }
    
    var mode: Mode
    
    /// The database connection in which the change has just happened
    public var database: Database {
        switch mode {
        case .initialSync(let db): return db
        case .async(_, let db): return db
        }
    }
    
    init(_ mode: Mode) {
        self.mode = mode
    }
}

extension ObservableType where E == ChangeToken {
    /// Transforms a sequence of change tokens into a sequence of values fetched
    /// from the database.
    ///
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    /// - parameter fetch: A function that accepts a database connection.
    /// - returns: An observable sequence whose elements are the result of
    ///   invoking the fetch function.
    public func mapFetch<ResultType>(resultQueue: DispatchQueue = DispatchQueue.main, _ fetch: @escaping (Database) throws -> ResultType) -> Observable<ResultType> {
        return MapFetch(
            source: asObservable(),
            fetch: fetch,
            resultQueue: resultQueue)
            .asObservable()
    }
}
