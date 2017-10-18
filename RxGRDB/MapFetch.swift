#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// An observable that fetches results from database connections and emits
/// them asynchronously.
///
/// TODO: tell how to create one
class MapFetch<ResultType> : ObservableType {
    typealias E = ResultType
    
    private let changeTokens: Observable<ChangeToken>
    private let resultQueue: DispatchQueue
    private let fetch: (Database) throws -> ResultType
    
    /// TODO
    init(source changeTokens: Observable<ChangeToken>, fetch: @escaping (Database) throws -> ResultType, resultQueue: DispatchQueue) {
        self.changeTokens = changeTokens
        self.fetch = fetch
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var dbSubscription: Disposable! = nil
        let subscription = Disposables.create {
            dbSubscription.dispose()
        }
        
        // Makes sure fetched results are ordered like change tokens
        let orderingQueue = DispatchQueue(label: "RxGRDB.MapFetch")
        
        // Be ready to handle subscription tokens
        var subscriptionDone = false
        var subscriptionElement: E? = nil
        
        dbSubscription = changeTokens.subscribe { event in
            switch event {
            case .error(let error): observer.on(.error(error))
            case .completed: observer.on(.completed)
            case .next(let changeToken):
                switch changeToken.kind {
                    
                case .databaseSubscription(let db):
                    if subscriptionDone {
                        fatalError("Scheduling error: databaseSubscription token must happen first and once, or never")
                    }
                    subscriptionDone = true
                    
                    do {
                        subscriptionElement = try self.fetch(db)
                    } catch {
                        observer.on(.error(error))
                    }
                    
                case .subscription:
                    guard let element = subscriptionElement else {
                        fatalError("Scheduling error: subscription token must happen after databaseSubscription token")
                    }
                    subscriptionElement = nil
                    observer.onNext(element)

                case .change(let writer, _):
                    subscriptionDone = true
                    
                    // We only need a read access to fetch values, and thus want
                    // to release the writer queue as soon as possible. This is
                    // the exact job of the writer.readFromCurrentState
                    // method.
                    //
                    // This method can be synchronous, or asynchrounous,
                    // depending on the actual type of database writer.
                    //
                    // Finally, we want to emit the fetched results in the
                    // same order as the database changes.
                    //
                    // => A semaphore notifies when the fetch is done, and the
                    // serial orderingQueue takes care of ordering:
                    
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
                            switch result {
                            case .success(let results):
                                observer.on(.next(results))
                            case .failure(let error):
                                observer.on(.error(error))
                            }
                        }
                    }
                }
            }
        }
        return subscription
    }
}
