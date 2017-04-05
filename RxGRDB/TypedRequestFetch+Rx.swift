import Foundation
import GRDB
import RxSwift

extension Reactive where Base: TypedRequest, Base.Fetched: RowConvertible {
    /// Returns an Observable that emits a array of records immediately on
    /// subscription, and later, on resultQueue, after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        return RequestFetchObservable(
            writer: writer,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    /// Returns an Observable that emits a single option record immediately on
    /// subscription, and later, on resultQueue, after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        return RequestFetchObservable(
            writer: writer,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue).asObservable()
    }
}

final class RequestFetchObservable<R: Request, ResultType> : ObservableType {
    typealias E = ResultType
    
    let writer: DatabaseWriter
    let request: R
    let resultQueue: DispatchQueue
    let fetch: (Database) throws -> ResultType
    
    init(writer: DatabaseWriter, request: R, fetch: @escaping (Database) throws -> ResultType, resultQueue: DispatchQueue) {
        self.writer = writer
        self.request = request
        self.fetch = fetch
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let orderingQueue = DispatchQueue(label: "RxGRDB.results")
        var initial = true
        return AnyRequest(request).rx
            .changes(in: writer)
            .subscribe { event in
                switch event {
                case .error(let error): observer.onError(error)
                case .completed: observer.onCompleted()
                case .next(let db):
                    if initial {
                        // Emit immediately on subscription
                        initial = false
                        do {
                            try observer.onNext(self.fetch(db))
                        } catch {
                            observer.onError(error)
                        }
                        return
                    }
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var result: Result<E>? = nil
                    do {
                        try self.writer.readFromCurrentState { db in
                            result = Result { try self.fetch(db) }
                            semaphore.signal()
                        }
                    } catch {
                        result = .failure(error)
                        semaphore.signal()
                    }
                    
                    orderingQueue.async {
                        _ = semaphore.wait(timeout: .distantFuture)
                        
                        // TODO: don't emit if subscription has been disposed
                        self.resultQueue.async {
                            switch result! {
                            case .success(let results):
                                observer.onNext(results)
                            case .failure(let error):
                                observer.onError(error)
                            }
                        }
                    }
                }
        }
    }
}
