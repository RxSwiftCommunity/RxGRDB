import Foundation
#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// MARK: - Count

// TODO: consider performing distinctUntilChanged comparisons in some background queue
extension Reactive where Base: FetchRequest & DatabaseRegionConvertible {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.all()
    ///     request.rx
    ///         .fetchCount(in: dbQueue)
    ///         .subscribe(onNext: { count in
    ///             print("Number of players has changed: \(count)")
    ///         })
    ///
    /// By default, all values are emitted on the main dispatch queue. If you
    /// give a *scheduler*, values are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchCount(in: dbQueue)
    ///         .subscribe(onNext: { count in
    ///             // on the main queue
    ///             print("Number of players has changed: \(count)")
    ///         })
    ///     // <- here "Number of players has changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchCount(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { count in
    ///             // on the main queue
    ///             print("Number of players has changed: \(count)")
    ///         })
    ///     // <- here "Number of players has changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchCount(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Int>
    {
        let request = base
        return AnyDatabaseWriter(writer).rx
            .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                try request.fetchCount($0)
        }
    }
}

// MARK: - FetchableRecord

extension Reactive where Base: FetchRequest & DatabaseRegionConvertible, Base.RowDecoder: FetchableRecord {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.all()
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { players: [Player] in
    ///             print("Players have changed")
    ///         })
    ///
    /// By default, all records are emitted on the main dispatch queue. If you
    /// give a *scheduler*, records are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { players: [Player] in
    ///             // on the main queue
    ///             print("Players have changed")
    ///         })
    ///     // <- here "Players have changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { players: [Player] in
    ///             // on the main queue
    ///             print("Players have changed")
    ///         })
    ///     // <- here "Players have changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try Row.fetchAll($0, request)
                }
                .distinctUntilChanged(==)
                .map { (rows: [Row]) in rows.map(Base.RowDecoder.init) }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchAll($0)
            }
        }
    }
    
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.filter(key: 1)
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { player: Player? in
    ///             print("Player 1 has changed")
    ///         })
    ///
    /// By default, all records are emitted on the main dispatch queue. If you
    /// give a *scheduler*, records are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { player: Player? in
    ///             // on the main queue
    ///             print("Player 1 has changed")
    ///         })
    ///     // <- here "Player 1 has changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { player: Player? in
    ///             // on the main queue
    ///             print("Player 1 has changed")
    ///         })
    ///     // <- here "Player 1 has changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try Row.fetchOne($0, request)
                }
                .distinctUntilChanged(==)
                .map { (row: Row?) in row.map(Base.RowDecoder.init) }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchOne($0)
            }
        }
    }
}

// MARK: - Row

extension Reactive where Base: FetchRequest & DatabaseRegionConvertible, Base.RowDecoder: Row {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<Row>("SELECT * FROM player")
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { rows: [Row] in
    ///             print("Players have changed")
    ///         })
    ///
    /// By default, all rows are emitted on the main dispatch queue. If you
    /// give a *scheduler*, rows are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { rows: [Row] in
    ///             // on the main queue
    ///             print("Players have changed")
    ///         })
    ///     // <- here "Players have changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { rows: [Row] in
    ///             // on the main queue
    ///             print("Players have changed")
    ///         })
    ///     // <- here "Players have changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchAll($0)
                }
                .distinctUntilChanged(==)
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchAll($0)
            }
        }
    }
    
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<Row>("SELECT * FROM player WHERE id = 1")
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { row: Row? in
    ///             print("Player 1 has changed")
    ///         })
    ///
    /// By default, all rows are emitted on the main dispatch queue. If you
    /// give a *scheduler*, rows are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { row: Row? in
    ///             // on the main queue
    ///             print("Player 1 has changed")
    ///         })
    ///     // <- here "Player 1 has changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { row: Row? in
    ///             // on the main queue
    ///             print("Player 1 has changed")
    ///         })
    ///     // <- here "Player 1 has changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchOne($0)
                }
                .distinctUntilChanged(==)
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchOne($0)
            }
        }
    }
}

// MARK: - DatabaseValueConvertible

extension Reactive where Base: FetchRequest & DatabaseRegionConvertible, Base.RowDecoder: DatabaseValueConvertible {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.select(Column("name")).asRequest(of: String.self)
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { names: [String] in
    ///             print("Player names have changed")
    ///         })
    ///
    /// By default, all values are emitted on the main dispatch queue. If you
    /// give a *scheduler*, values are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { names: [String] in
    ///             // on the main queue
    ///             print("Player names have changed")
    ///         })
    ///     // <- here "Player names have changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { names: [String] in
    ///             // on the main queue
    ///             print("Player names have changed")
    ///         })
    ///     // <- here "Player names have changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try DatabaseValue.fetchAll($0, request)
                }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchAll($0)
            }
        }
    }
    
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<String>("SELECT name FROM player ORDER BY score DESC")
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { bestPlayerName: String? in
    ///             print("Best player has changed")
    ///         })
    ///
    /// By default, all values are emitted on the main dispatch queue. If you
    /// give a *scheduler*, values are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { bestPlayerName: String? in
    ///             // on the main queue
    ///             print("Best player has changed")
    ///         })
    ///     // <- here "Best player has changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { bestPlayerName: String? in
    ///             // on the main queue
    ///             print("Best player has changed")
    ///         })
    ///     // <- here "Best player has changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try DatabaseValue.fetchOne($0, request)
                }
                .distinctUntilChanged(==)
                .map { (dbValue: DatabaseValue?) in dbValue.map { $0.losslessConvert() as Base.RowDecoder? } ?? nil }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchOne($0)
            }
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

extension Reactive where Base: FetchRequest & DatabaseRegionConvertible, Base.RowDecoder: _OptionalProtocol, Base.RowDecoder._Wrapped: DatabaseValueConvertible {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.select(Column("name")).asRequest(of: Optional<String>.self)
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { names: [String?] in
    ///             print("Player names have changed")
    ///         })
    ///
    /// By default, all values are emitted on the main dispatch queue. If you
    /// give a *scheduler*, values are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { names: [String?] in
    ///             // on the main queue
    ///             print("Player names have changed")
    ///         })
    ///     // <- here "Player names have changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { names: [String?] in
    ///             // on the main queue
    ///             print("Player names have changed")
    ///         })
    ///     // <- here "Player names have changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try DatabaseValue.fetchAll($0, request)
                }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder._Wrapped? } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try Optional<Base.RowDecoder._Wrapped>.fetchAll($0, request)
            }
        }
    }
}

// MARK: - DatabaseValueConvertible & StatementColumnConvertible

extension Reactive where Base: FetchRequest & DatabaseRegionConvertible, Base.RowDecoder: DatabaseValueConvertible & StatementColumnConvertible {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.select(Column("name")).asRequest(of: String.self)
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { names: [String] in
    ///             print("Player names have changed")
    ///         })
    ///
    /// By default, all values are emitted on the main dispatch queue. If you
    /// give a *scheduler*, values are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue)
    ///         .subscribe(onNext: { names: [String] in
    ///             // on the main queue
    ///             print("Player names have changed")
    ///         })
    ///     // <- here "Player names have changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchAll(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { names: [String] in
    ///             // on the main queue
    ///             print("Player names have changed")
    ///         })
    ///     // <- here "Player names have changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try DatabaseValue.fetchAll($0, request)
                }
                .distinctUntilChanged(==)
                .map { (dbValues: [DatabaseValue]) in dbValues.map { $0.losslessConvert() as Base.RowDecoder } }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchAll($0)
            }
        }
    }
    
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<String>("SELECT name FROM player ORDER BY score DESC")
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { bestPlayerName: String? in
    ///             print("Best player has changed")
    ///         })
    ///
    /// By default, all values are emitted on the main dispatch queue. If you
    /// give a *scheduler*, values are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue)
    ///         .subscribe(onNext: { bestPlayerName: String? in
    ///             // on the main queue
    ///             print("Best player has changed")
    ///         })
    ///     // <- here "Best player has changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetchOne(in: dbQueue, scheduler: MainScheduler.instance)
    ///         .subscribe(onNext: { bestPlayerName: String? in
    ///             // on the main queue
    ///             print("Best player has changed")
    ///         })
    ///     // <- here "Best player has changed" may not be printed yet
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
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
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try DatabaseValue.fetchOne($0, request)
                }
                .distinctUntilChanged(==)
                .map { (dbValue: DatabaseValue?) in dbValue.map { $0.losslessConvert() as Base.RowDecoder? } ?? nil }
        } else {
            return AnyDatabaseWriter(writer).rx
                .fetch(from: [request], startImmediately: startImmediately, scheduler: scheduler) {
                    try request.fetchOne($0)
            }
        }
    }
}
