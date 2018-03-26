#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// Fetch tokens let you turn notifications of database changes into
/// fetched values.
///
/// To generate fetch tokens, see `DatabaseWriter.rx.fetchTokens(in:startImmediately:scheduler:)`.
///
/// To turn them into fetched values, see `ObservableType.mapFetch(_:)`.
///
///     dbQueue.rx
///         .fetchTokens(in: [...]) // observe changes in some requests
///         .mapFetch { db: Database in
///             return ...          // fetch some values
///         }
///         .subscribe(onNext: { values in
///             ...                 // use fetched values
///         }
public struct FetchToken {
    /// Not public: the kind of token
    enum Kind {
        /// Emitted upon subscription, from the database writer dispatch queue.
        case databaseSubscription(Database)
        
        /// Emitted upon subscription, from the scheduler dispatch queue.
        case subscription
        
        /// Emitted from the database writer dispatch queue.
        case change(DatabaseWriter, FetchTokenScheduler)
    }
    
    var kind: Kind
}

/// Not public: how fetched values should be scheduled
enum FetchTokenScheduler {
    /// Schedules with an RxSwift scheduler
    case scheduler(ImmediateSchedulerType)
    
    /// Schedules on the main queue. This specific scheduling technique
    /// guarantees that the initially fetched values are synchronous delivered
    /// on the main queue. That last guarantee can't be fulfilled by
    /// MainScheduler.instance.
    case mainQueue
    
    func schedule(action: @escaping () -> Void) {
        switch self {
        case .scheduler(let scheduler):
            _ = scheduler.schedule(()) { _ in
                action()
                return Disposables.create()
            }
        case .mainQueue:
            if DispatchQueue.isMain {
                action()
            } else {
                DispatchQueue.main.async(execute: action)
            }
        }
    }
}

extension DispatchQueue {
    private static var token: DispatchSpecificKey<()> = {
        let key = DispatchSpecificKey<()>()
        DispatchQueue.main.setSpecific(key: key, value: ())
        return key
    }()
    
    static var isMain: Bool {
        return DispatchQueue.getSpecific(key: token) != nil
    }
}

extension ObservableType where E == FetchToken {
    /// Transforms a sequence of fetch tokens into a sequence of fetched values.
    ///
    /// - parameter fetch: A function that accepts a database connection and
    ///   returns fetched value.
    /// - returns: An observable sequence whose elements are the fetched values.
    public func mapFetch<R>(_ fetch: @escaping (Database) throws -> R) -> Observable<R> {
        return MapFetch(
            source: asObservable(),
            fetch: fetch)
            .asObservable()
    }
}

/// Fixit for legacy API
@available(*, unavailable, renamed:"FetchToken")
public typealias ChangeToken = FetchToken
