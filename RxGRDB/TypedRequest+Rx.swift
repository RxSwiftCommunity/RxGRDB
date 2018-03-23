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
    /// All arrays are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchAll(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<[Base.RowDecoder]>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try Row.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (rows: [Row]) in rows.map { Base.RowDecoder.init(row: $0) } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchAll($0) }
        }
    }
    
    /// Returns an Observable that emits an optional record after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// All records are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchOne(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<Base.RowDecoder?>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try Row.fetchOne($0, request) }
                .distinctUntilChanged(==)
                .map { (row: Row?) in row.map { Base.RowDecoder.init(row: $0) } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchOne($0) }
        }
    }
}

// MARK: - Row

extension Reactive where Base: TypedRequest, Base.RowDecoder: Row {
    /// Returns an Observable that emits an array of rows after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// All arrays are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchAll(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<[Row]>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchAll($0) }
                .distinctUntilChanged(==)
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchAll($0) }
        }
    }
    
    /// Returns an Observable that emits an optional row after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// All rows are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchOne(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<Row?>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchOne($0) }
                .distinctUntilChanged(==)
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchOne($0) }
        }
        
    }
}

// MARK: - DatabaseValueConvertible

extension Reactive where Base: TypedRequest, Base.RowDecoder: DatabaseValueConvertible {
    /// Returns an Observable that emits an array of values after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// All arrays are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchAll(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<[Base.RowDecoder]>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try DatabaseValue.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchAll($0) }
        }
    }
    
    /// Returns an Observable that emits an optional value after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// All values are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchOne(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<Base.RowDecoder?>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try DatabaseValue.fetchOne($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValue: DatabaseValue?) in dbValue.map { $0.losslessConvert() as Base.RowDecoder? } ?? nil }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchOne($0) }
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
    /// All arrays are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchAll(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<[Base.RowDecoder._Wrapped?]>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try DatabaseValue.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder._Wrapped? } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try Optional<Base.RowDecoder._Wrapped>.fetchAll($0, request) }
        }
    }
}

// MARK: - DatabaseValueConvertible & StatementColumnConvertible

extension Reactive where Base: TypedRequest, Base.RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    /// Returns an Observable that emits an array of values after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// All arrays are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchAll(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<[Base.RowDecoder]>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try DatabaseValue.fetchAll($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchAll($0) }
        }
    }
    
    /// Returns an Observable that emits an optional value after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// All values are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchOne(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        distinctUntilChanged: Bool = false)
        -> Observable<Base.RowDecoder?>
    {
        let request = base
        if distinctUntilChanged {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try DatabaseValue.fetchOne($0, request) }
                .distinctUntilChanged(==)
                .map { (dbValue: DatabaseValue?) in dbValue.map { $0.losslessConvert() as Base.RowDecoder? } ?? nil }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
                .mapFetch { try request.fetchOne($0) }
        }
    }
}
