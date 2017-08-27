import Foundation
#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// MARK: - RowConvertible

// TODO: consider performing distinctUntilChanged comparisons in some background queue
extension Reactive where Base: TypedRequest, Base.RowDecoder: RowConvertible {
    /// Returns an Observable that emits an array of records after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.RowDecoder]> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try Row.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (rows: [Row]) in rows.map { Base.RowDecoder.init(row: $0) } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchAll($0) }
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
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.RowDecoder?> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try Row.fetchOne($0, request) }
                .distinctUntilChanged(==)
                .map { (row: Row?) in row.map { Base.RowDecoder.init(row: $0) } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchOne($0) }
        }
    }
}

// MARK: - Row

extension Reactive where Base: TypedRequest, Base.RowDecoder: Row {
    /// Returns an Observable that emits an array of rows after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Row]> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchAll($0) }
                .distinctUntilChanged(==)
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchAll($0) }
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
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Row?> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchOne($0) }
                .distinctUntilChanged(==)
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchOne($0) }
        }
        
    }
}

// MARK: - DatabaseValueConvertible

extension Reactive where Base: TypedRequest, Base.RowDecoder: DatabaseValueConvertible {
    /// Returns an Observable that emits an array of values after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.RowDecoder]> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try DatabaseValue.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchAll($0) }
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
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.RowDecoder?> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try DatabaseValue.fetchOne($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValue: DatabaseValue?) in dbValue.map { $0.losslessConvert() as Base.RowDecoder? } ?? nil }
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchOne($0) }
        }
    }
}

// MARK: - Optional DatabaseValueConvertible

public protocol _OptionalProtocol {
    associatedtype _Wrapped
}

extension Optional : _OptionalProtocol {
    public typealias _Wrapped = Wrapped
}

extension Reactive where Base: TypedRequest, Base.RowDecoder: _OptionalProtocol, Base.RowDecoder._Wrapped: DatabaseValueConvertible {
    /// Returns an Observable that emits an array of values after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.RowDecoder._Wrapped?]> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try DatabaseValue.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder._Wrapped? } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try Optional<Base.RowDecoder._Wrapped>.fetchAll($0, request) }
        }
    }
}

// MARK: - DatabaseValueConvertible & StatementColumnConvertible

extension Reactive where Base: TypedRequest, Base.RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    /// Returns an Observable that emits an array of values after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first array
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.RowDecoder]> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try DatabaseValue.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchAll($0) }
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
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, synchronizedStart: Bool = true, distinctUntilChanged: Bool = false, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.RowDecoder?> {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try DatabaseValue.fetchOne($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValue: DatabaseValue?) in dbValue.map { $0.losslessConvert() as Base.RowDecoder? } ?? nil }
        } else {
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request], synchronizedStart: synchronizedStart)
                .mapFetch(resultQueue: resultQueue) { try request.fetchOne($0) }
        }
    }
}
