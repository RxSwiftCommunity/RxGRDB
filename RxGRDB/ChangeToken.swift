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
    /// Not public: the kind of change token
    enum Kind {
        /// Emitted synchronously upon subscription, from the database writer
        /// dispatch queue.
        case databaseSubscription(Database)
        
        /// Emitted synchronously upon subscription, from the subscription
        /// dispatch queue.
        case subscription
        
        /// Emitted from the database writer dispatch queue.
        case change(DatabaseWriter, Database)
    }
    
    var kind: Kind
    
    init(_ kind: Kind) {
        self.kind = kind
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
    public func mapFetch<R>(resultQueue: DispatchQueue = DispatchQueue.main, _ fetch: @escaping (Database) throws -> R) -> Observable<R> {
        return MapFetch(
            source: asObservable(),
            fetch: fetch,
            resultQueue: resultQueue)
            .asObservable()
    }
}
