#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// An observable that fetches results from database connections and emits
/// them asynchronously.
class MapFetch<ResultType> : ObservableType {
    typealias E = ResultType
    
    private let changeTokens: Observable<ChangeToken>
    private let resultQueue: DispatchQueue
    private let fetch: (Database) throws -> ResultType
    
    /// Creates a MapFetch observable.
    ///
    /// - precondition: This observable must be subscribed on resultQueue.
    ///
    /// - parameters:
    ///   - source: An observable sequence of ChangeToken
    ///   - fetch: A closure that fetches elements
    ///   - resultQueue: The dispatch queue where elements are emitted.
    init(
        source changeTokens: Observable<ChangeToken>,
        resultQueue: DispatchQueue,
        fetch: @escaping (Database) throws -> ResultType)
    {
        self.changeTokens = changeTokens
        self.resultQueue = resultQueue
        self.fetch = fetch
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var dbSubscription: Disposable! = nil
        let subscription = Disposables.create {
            dbSubscription.dispose()
        }
        
        // The value eventually fetched on subscription
        var initialResult: Result<ResultType>? = nil
        
        // Makes sure fetched results are ordered like change tokens
        let orderingQueue = DispatchQueue(label: "RxGRDB.MapFetch")
        
        dbSubscription = changeTokens.subscribe { event in
            switch event {
            case .error(let error): observer.on(.error(error))
            case .completed: observer.on(.completed)
            case .next(let changeToken):
                switch changeToken.kind {
                    
                case .databaseSubscription(let db):
                    // Current dispatch queue: the database writer dispatch queue
                    // This token is emitted synchronously upon subscription.
                    initialResult = Result { try self.fetch(db) }
                    
                case .subscription:
                    // Current dispatch queue: the subscription dispatch queue,
                    // which happens to be `resultQueue`, per precondition.
                    //
                    // This token is emitted synchronously upon subscription,
                    // after `databaseSubscription`.
                    //
                    // NB: this code executes concurrently with database writes.
                    // Several `change` token may have already been received.
                    observer.onResult(initialResult!)
                    
                case .change(let writer, _):
                    // Current dispatch queue: the database writer dispatch queue
                    // This token is emitted after a transaction has been committed.
                    //
                    // We need a read access to fetch values, and we should
                    // release the writer queue as soon as possible.
                    //
                    // This is the exact job of the writer.readFromCurrentState
                    // method. This method can be synchronous, or
                    // asynchrounous, depending on the actual type of
                    // database writer (DatabaseQueue or DatabasePool).
                    //
                    // Elements must be emitted in the same order as the
                    // change tokens: the serial orderingQueue takes care of
                    // FIFO ordering, and a semaphore notifies when the
                    // fetch is done.
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var result: Result<E>? = nil
                    do {
                        try writer.readFromCurrentState { db in
                            if !subscription.isDisposed {
                                result = Result { try self.fetch(db) }
                            }
                            semaphore.signal()
                        }
                    } catch {
                        result = .failure(error)
                        semaphore.signal()
                    }
                    
                    orderingQueue.async {
                        _ = semaphore.wait(timeout: .distantFuture)
                        
                        guard let result = result else { return }
                        guard !subscription.isDisposed else { return }
                        
                        self.resultQueue.async {
                            guard !subscription.isDisposed else { return }
                            observer.onResult(result)
                        }
                    }
                }
            }
        }
        
        return subscription
    }
}
