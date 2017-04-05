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
    
    /// Returns an Observable that emits a single optional record immediately on
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

extension Reactive where Base: TypedRequest, Base.Fetched: Row {
    /// Returns an Observable that emits a array of rows immediately on
    /// subscription, and later, on resultQueue, after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Row]> {
        return RequestFetchObservable(
            writer: writer,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    /// Returns an Observable that emits a single optional row immediately on
    /// subscription, and later, on resultQueue, after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Row?> {
        return RequestFetchObservable(
            writer: writer,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue).asObservable()
    }
}

extension Reactive where Base: TypedRequest, Base.Fetched: DatabaseValueConvertible {
    /// Returns an Observable that emits a array of values immediately on
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
    
    /// Returns an Observable that emits a single optional value immediately on
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
