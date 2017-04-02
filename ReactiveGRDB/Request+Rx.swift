import GRDB
import RxSwift

extension QueryInterfaceRequest : ReactiveCompatible { }
extension SQLRequest : ReactiveCompatible { }
extension AnyRequest : ReactiveCompatible { }
extension AnyTypedRequest : ReactiveCompatible { }

extension Reactive where Base: Request {
    /// Returns an Observable that emits a writer database connection
    /// immediately on subscription, and later after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    public func changes(in writer: DatabaseWriter) -> Observable<Database> {
        return RequestChangesObservable(writer: writer, request: base).asObservable()
    }
}

final class RequestChangesObservable<R: Request> : ObservableType {
    typealias E = Database
    
    let writer: DatabaseWriter
    let request: R
    
    init(writer: DatabaseWriter, request: R) {
        self.writer = writer
        self.request = request
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let selectionInfo: SelectStatement.SelectionInfo
        do {
            selectionInfo = try writer.unsafeRead { db -> SelectStatement.SelectionInfo in
                let (statement, _) = try request.prepare(db)
                return statement.selectionInfo
            }
        } catch {
            observer.onError(error)
            observer.onCompleted()
            return Disposables.create()
        }
        
        return selectionInfo.rx.changes(in: writer).subscribe(observer)
    }
}

final class RequestFetchObservable<R: Request, ResultType> : ObservableType {
    typealias E = ResultType
    
    let writer: DatabaseWriter
    let request: R
    let resultQueue: DispatchQueue?
    let fetch: (Database) throws -> ResultType
    
    init(writer: DatabaseWriter, request: R, fetch: @escaping (Database) throws -> ResultType, resultQueue: DispatchQueue? = nil) {
        self.writer = writer
        self.request = request
        self.fetch = fetch
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let orderingQueue = DispatchQueue(label: "ReactiveGRDB.results")
        
        var initial = true
        let disposable = AnyRequest(request).rx.changes(in: writer).subscribe { event in
            switch event {
            case .next(let db):
                if initial {
                    // Emit immediately on subscription
                    initial = false
                    do {
                        try observer.onNext(self.fetch(db))
                    } catch {
                        observer.onError(error)
                    }
                } else {
                    let semaphore = DispatchSemaphore(value: 0)
                    var result: Result<E>? = nil
                    do {
                        try self.writer.readFromCurrentState { db in
                            result = Result.wrap { try self.fetch(db) }
                            semaphore.signal()
                        }
                    } catch {
                        result = .failure(error)
                        semaphore.signal()
                    }
                    
                    orderingQueue.async {
                        _ = semaphore.wait(timeout: .distantFuture)
                        
                        func notify() {
                            switch result! {
                            case .success(let results):
                                observer.onNext(results)
                            case .failure(let error):
                                observer.onError(error)
                            }
                        }
                        
                        if let resultQueue = self.resultQueue {
                            resultQueue.async(execute: notify)
                        } else {
                            notify()
                        }
                    }
                }
            case .error(let error):
                observer.onError(error)
            case .completed:
                observer.onCompleted()
            }
        }
        
        return disposable
    }
}

private enum Result<Value> {
    case success(Value)
    case failure(Error)
    
    static func wrap(_ value: () throws -> Value) -> Result<Value> {
        do {
            return try .success(value())
        } catch {
            return .failure(error)
        }
    }
    
    /// Evaluates the given closure when this `Result` is a success, passing the
    /// unwrapped value as a parameter.
    ///
    /// Use the `map` method with a closure that does not throw. For example:
    ///
    ///     let possibleData: Result<Data> = .success(Data())
    ///     let possibleInt = possibleData.map { $0.count }
    ///     try print(possibleInt.unwrap())
    ///     // Prints "0"
    ///
    ///     let noData: Result<Data> = .failure(error)
    ///     let noInt = noData.map { $0.count }
    ///     try print(noInt.unwrap())
    ///     // Throws error
    ///
    /// - parameter transform: A closure that takes the success value of
    ///   the instance.
    /// - returns: A `Result` containing the result of the given closure. If
    ///   this instance is a failure, returns the same failure.
    func map<T>(_ transform: (Value) -> T) -> Result<T> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
}
