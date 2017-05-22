import Foundation
#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// MARK: - RowConvertible

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
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        if distinctUntilChanged {
            let rows = RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try Row.fetchAll($0, self.base) },
                resultQueue: resultQueue)
            return rows
                .distinctUntilChanged(==)
                .map { (rows: [Row]) in rows.map { Base.Fetched.init(row: $0) } }
                .asObservable()
        } else {
            return RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try self.base.fetchAll($0) },
                resultQueue: resultQueue)
                .asObservable()
        }
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
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        if distinctUntilChanged {
            let row = RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try Row.fetchOne($0, self.base) },
                resultQueue: resultQueue)
            return row
                .distinctUntilChanged(==)
                .map { (row: Row?) in row.map { Base.Fetched.init(row: $0) } }
                .asObservable()
        } else {
            return RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try self.base.fetchOne($0) },
                resultQueue: resultQueue)
                .asObservable()
        }
    }
}

// MARK: - Row

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
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Row]> {
        let rows = RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue)
        
        if distinctUntilChanged {
            return rows.distinctUntilChanged(==).asObservable()
        } else {
            return rows.asObservable()
        }
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
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Row?> {
        let row = RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue)
        
        if distinctUntilChanged {
            return row.distinctUntilChanged(==).asObservable()
        } else {
            return row.asObservable()
        }

    }
}

// MARK: - DatabaseValueConvertible

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
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        if distinctUntilChanged {
            let databaseValues = RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try DatabaseValue.fetchAll($0, self.base) },
                resultQueue: resultQueue)
            return databaseValues
                .distinctUntilChanged(==)
                .map { (databaseValues: [DatabaseValue]) in databaseValues.map { $0.losslessConvert() as Base.Fetched } }
                .asObservable()
        } else {
            return RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try self.base.fetchAll($0) },
                resultQueue: resultQueue)
                .asObservable()
        }
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
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        if distinctUntilChanged {
            let databaseValue = RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try DatabaseValue.fetchOne($0, self.base) },
                resultQueue: resultQueue)
            return databaseValue
                .distinctUntilChanged(==)
                .map { (databaseValue: DatabaseValue?) in databaseValue.map { $0.losslessConvert() as Base.Fetched? } ?? nil }
                .asObservable()
        } else {
            return RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try self.base.fetchOne($0) },
                resultQueue: resultQueue)
                .asObservable()
        }
    }
}

// MARK: - Optional DatabaseValueConvertible

/// This protocol is an implementation detail of GRDB. Don't use it.
public protocol _OptionalFetchable {
    associatedtype _Wrapped
}

/// This conformance is an implementation detail of GRDB. Don't rely on it.
extension Optional : _OptionalFetchable {
    public typealias _Wrapped = Wrapped
}

extension Reactive where Base: TypedRequest, Base.Fetched: _OptionalFetchable, Base.Fetched._Wrapped: DatabaseValueConvertible {
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
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched._Wrapped?]> {
        if distinctUntilChanged {
            let databaseValues = RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try DatabaseValue.fetchAll($0, self.base) },
                resultQueue: resultQueue)
            return databaseValues
                .distinctUntilChanged(==)
                .map { (databaseValues: [DatabaseValue]) in databaseValues.map { $0.losslessConvert() as Base.Fetched._Wrapped? } }
                .asObservable()
        } else {
            return RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try Optional<Base.Fetched._Wrapped>.fetchAll($0, self.base) },
                resultQueue: resultQueue)
                .asObservable()
        }
    }
}

// MARK: - DatabaseValueConvertible & StatementColumnConvertible

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
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        if distinctUntilChanged {
            let databaseValues = RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try DatabaseValue.fetchAll($0, self.base) },
                resultQueue: resultQueue)
            return databaseValues
                .distinctUntilChanged(==)
                .map { (databaseValues: [DatabaseValue]) in databaseValues.map { $0.losslessConvert() as Base.Fetched } }
                .asObservable()
        } else {
            return RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try self.base.fetchAll($0) },
                resultQueue: resultQueue)
                .asObservable()
        }
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
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        if distinctUntilChanged {
            let databaseValue = RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try DatabaseValue.fetchOne($0, self.base) },
                resultQueue: resultQueue)
            return databaseValue
                .distinctUntilChanged(==)
                .map { (databaseValue: DatabaseValue?) in databaseValue.map { $0.losslessConvert() as Base.Fetched? } ?? nil }
                .asObservable()
        } else {
            return RequestFetchObservable(
                writer: writer,
                synchronizedStart: synchronizedStart,
                request: base,
                fetch: { try self.base.fetchOne($0) },
                resultQueue: resultQueue)
                .asObservable()
        }
    }
}
