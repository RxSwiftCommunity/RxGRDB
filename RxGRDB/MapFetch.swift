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
        
        // Prevent user from feeding several .synchronizedStartInDatabase change tokens, because
        // we haven't guaranteed yet that this does not mess with the ordering of
        // fetched results.
        var allowsSynchronizedStart = true
        var synchronizedStartElement: E? = nil
        
        dbSubscription = changeTokens.subscribe { event in
            switch event {
            case .error(let error): observer.on(.error(error))
            case .completed: observer.on(.completed)
            case .next(let changeToken):
                switch changeToken.mode {
                    
                case .synchronizedStartInDatabase(let db):
                    guard allowsSynchronizedStart else {
                        fatalError("Wrong scheduling: synchronizedStartInDatabase must happen first and once, or never")
                    }
                    // No more .synchronizedStartInDatabase allowed
                    allowsSynchronizedStart = false
                    
                    do {
                        synchronizedStartElement = try self.fetch(db)
                    } catch {
                        observer.on(.error(error))
                    }
                    
                case .synchronizedStartInSubscription:
                    guard let element = synchronizedStartElement else {
                        fatalError("Wrong scheduling: synchronizedStartInSubscription must happen right after synchronizedStartInDatabase")
                    }
                    synchronizedStartElement = nil
                    observer.onNext(element)

                case .async(let writer, _):
                    // No more .synchronizedStartInDatabase allowed
                    allowsSynchronizedStart = false
                    
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
