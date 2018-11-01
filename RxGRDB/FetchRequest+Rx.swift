import Foundation
#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

// MARK: - Count

extension Reactive where Base: FetchRequest {
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchCount(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Int>
    {
        return ValueObservation.trackingCount(base).rx.fetch(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
}

// MARK: - FetchableRecord

extension Reactive where Base: FetchRequest, Base.RowDecoder: FetchableRecord {
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    {
        return ValueObservation.trackingAll(base).rx.fetch(
            in: reader,
            startImmediately:
            startImmediately,
            scheduler: scheduler)
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    {
        return ValueObservation.trackingOne(base).rx.fetch(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
}

// MARK: - Row

extension Reactive where Base: FetchRequest, Base.RowDecoder == Row {
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Row]>
    {
        return ValueObservation.trackingAll(base).rx.fetch(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Row?>
    {
        return ValueObservation.trackingOne(base).rx.fetch(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
}

// MARK: - DatabaseValueConvertible

extension Reactive where Base: FetchRequest, Base.RowDecoder: DatabaseValueConvertible {
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    {
        return ValueObservation.trackingAll(base).rx.fetch(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    {
        return ValueObservation.trackingOne(base).rx.fetch(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
}

// MARK: - Optional DatabaseValueConvertible

extension Reactive where Base: FetchRequest, Base.RowDecoder: _OptionalProtocol, Base.RowDecoder._Wrapped: DatabaseValueConvertible {
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
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder._Wrapped?]>
    {
        return ValueObservation.trackingAll(base).rx.fetch(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
}
