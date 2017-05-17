import Foundation
#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension Reactive where Base: TypedRequest, Base.Fetched: RowConvertible {
    /// Returns an Observable that emits an array of records after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    /// Returns an Observable that emits an optional record after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first record
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue).asObservable()
    }
}

extension Reactive where Base: TypedRequest, Base.Fetched: Row {
    /// Returns an Observable that emits an array of rows after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Row]> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    /// Returns an Observable that emits an optional row after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first row
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Row?> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue).asObservable()
    }
}

extension Reactive where Base: TypedRequest, Base.Fetched: DatabaseValueConvertible {
    /// Returns an Observable that emits an array of values after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    /// Returns an Observable that emits an optional value after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first value
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue).asObservable()
    }
}

extension Reactive where Base: TypedRequest, Base.Fetched: DatabaseValueConvertible & StatementColumnConvertible {
    /// Returns an Observable that emits an array of values after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    /// Returns an Observable that emits an optional value after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first value
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue).asObservable()
    }
}
