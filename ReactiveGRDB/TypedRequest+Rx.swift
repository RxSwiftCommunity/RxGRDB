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
        return FetchAllRowConvertibleObservable(writer: writer, request: base, resultQueue: resultQueue).asObservable()
    }
}

final class FetchAllRowConvertibleObservable<R: TypedRequest>: ObservableType where R.Fetched: RowConvertible {
    typealias E = [R.Fetched]
    
    let writer: DatabaseWriter
    let request: R
    let resultQueue: DispatchQueue?
    
    init(writer: DatabaseWriter, request: R, resultQueue: DispatchQueue? = nil) {
        self.writer = writer
        self.request = request
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let orderingQueue = DispatchQueue(label: "ReactiveGRDB.results")
        
        var initial = true
        let disposable = AnyRequest(request).rx.changes(in: writer).subscribe { event in
            switch event {
            case .next(let db):
                if initial {
                    initial = false
                    do {
                        try observer.onNext(self.request.fetchAll(db))
                    } catch {
                        observer.onError(error)
                    }
                } else {
                    let semaphore = DispatchSemaphore(value: 0)
                    var result: Result<E>? = nil
                    do {
                        try self.writer.readFromCurrentState { db in
                            result = Result.wrap { try self.request.fetchAll(db) }
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

public final class Item<T: RowConvertible> : RowConvertible, Equatable {
    let row: Row
    
    // Records are lazily loaded
    lazy var record: T = {
        var record = T(row: self.row)
        record.awakeFromFetch(row: self.row)
        return record
    }()
    
    public init(row: Row) {
        self.row = row.copy()
    }
    
    public static func ==(lhs: Item, rhs: Item) -> Bool {
        return lhs.row == rhs.row
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
