import Foundation
import GRDB
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
    ///         .observeCount(in: dbQueue)
    ///         .subscribe(onNext: { (count: Int) in
    ///             print("Fresh number of players: \(count)")
    ///         })
    ///
    /// All elements are emitted on the main queue by default, unless you
    /// provide a specific `scheduler`.
    ///
    /// If you set `startImmediately` to true (the default value), the first
    /// element is emitted immediately, from the current database state.
    /// Furthermore, this first element is emitted *synchronously* if and only
    /// if the observable is subscribed on the main queue, and is given a nil
    /// `scheduler` argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .observeCount(in: dbQueue)
    ///         .subscribe(onNext: { (count: Int) in
    ///             // on the main queue
    ///             print("Fresh number of players: \(count)")
    ///         })
    ///     // <- here "Fresh number of players" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeCount(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<Int>
    {
        return base.observationForCount().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeCount(on:in:startImmediately:)")
    public func fetchCount(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Int>
    {
        return observeCount(on: scheduler, in: reader, startImmediately: startImmediately)
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
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (players: [Player]) in
    ///             print("Fresh players: \(players)")
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
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (players: [Player]) in
    ///             // on the main queue
    ///             print("Fresh players: \(players)")
    ///         })
    ///     // <- here "Fresh players" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeAll(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<[Base.RowDecoder]>
    {
        return base.observationForAll().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeAll(on:in:startImmediately:)")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    {
        return observeAll(on: scheduler, in: reader, startImmediately: startImmediately)
    }

    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.filter(key: 1)
    ///     request.rx
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (player: Player?) in
    ///             print("Fresh player: \(player)")
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
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (player: Player?) in
    ///             // on the main queue
    ///             print("Fresh player: \(player)")
    ///         })
    ///     // <- here "Fresh player" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeFirst(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<Base.RowDecoder?>
    {
        return base.observationForFirst().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeFirst(on:in:startImmediately:)")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    {
        return observeFirst(on: scheduler, in: reader, startImmediately: startImmediately)
    }
}

// MARK: - Row

extension Reactive where Base: FetchRequest, Base.RowDecoder == Row {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player")
    ///     request.rx
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (rows: [Row]) in
    ///             print("Fresh rows: \(rows)")
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
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (rows: [Row]) in
    ///             // on the main queue
    ///             print("Fresh rows: \(rows)")
    ///         })
    ///     // <- here "Fresh rows" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeAll(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<[Row]>
    {
        return base.observationForAll().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeAll(on:in:startImmediately:)")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Row]>
    {
        return observeAll(on: scheduler, in: reader, startImmediately: startImmediately)
    }
    
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player WHERE id = 1")
    ///     request.rx
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (row: Row?) in
    ///             print("Fresh row: \(row)")
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
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (row: Row?) in
    ///             // on the main queue
    ///             print("Fresh row: \(row)")
    ///         })
    ///     // <- here "Fresh row" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeFirst(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<Row?>
    {
        return base.observationForFirst().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeFirst(on:in:startImmediately:)")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Row?>
    {
        return observeFirst(on: scheduler, in: reader, startImmediately: startImmediately)
    }
}

// MARK: - DatabaseValueConvertible

extension Reactive where Base: FetchRequest, Base.RowDecoder: DatabaseValueConvertible {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.select(Column("name"), as: String.self)
    ///     request.rx
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (names: [String]) in
    ///             print("Fresh names: \(names)")
    ///         })
    ///
    /// All elements are emitted on the main queue by default, unless you
    /// provide a specific `scheduler`.
    ///
    /// If you set `startImmediately` to true (the default value), the first
    /// element is emitted immediately, from the current database state.
    /// Furthermore, this first element is emitted *synchronously* if and only
    /// if the observable is subscribed on the main queue, and is given a nil
    /// `scheduler` argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (names: [String]) in
    ///             // on the main queue
    ///             print("Fresh names: \(names)")
    ///         })
    ///     // <- here "Fresh names" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeAll(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<[Base.RowDecoder]>
    {
        return base.observationForAll().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeAll(on:in:startImmediately:)")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    {
        return observeAll(on: scheduler, in: reader, startImmediately: startImmediately)
    }

    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<String>(sql: "SELECT name FROM player ORDER BY score DESC")
    ///     request.rx
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (name: String?) in
    ///             print("Fresh name: \(name)")
    ///         })
    ///
    /// All elements are emitted on the main queue by default, unless you
    /// provide a specific `scheduler`.
    ///
    /// If you set `startImmediately` to true (the default value), the first
    /// element is emitted immediately, from the current database state.
    /// Furthermore, this first element is emitted *synchronously* if and only
    /// if the observable is subscribed on the main queue, and is given a nil
    /// `scheduler` argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (name: String?) in
    ///             // on the main queue
    ///             print("Fresh name: \(name)")
    ///         })
    ///     // <- here "Fresh name" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeFirst(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<Base.RowDecoder?>
    {
        return base.observationForFirst().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeFirst(on:in:startImmediately:)")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    {
        return observeFirst(on: scheduler, in: reader, startImmediately: startImmediately)
    }
}

// MARK: - Optional DatabaseValueConvertible

extension Reactive where Base: FetchRequest, Base.RowDecoder: _OptionalProtocol, Base.RowDecoder._Wrapped: DatabaseValueConvertible {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.select(Column("name"), as: Optional<String>.self)
    ///     request.rx
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (names: [String?]) in
    ///             print("Fresh names: \(names)")
    ///         })
    ///
    /// All elements are emitted on the main queue by default, unless you
    /// provide a specific `scheduler`.
    ///
    /// If you set `startImmediately` to true (the default value), the first
    /// element is emitted immediately, from the current database state.
    /// Furthermore, this first element is emitted *synchronously* if and only
    /// if the observable is subscribed on the main queue, and is given a nil
    /// `scheduler` argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .observeAll(in: dbQueue)
    ///         .subscribe(onNext: { (names: [String?]) in
    ///             // on the main queue
    ///             print("Fresh names: \(names)")
    ///         })
    ///     // <- here "Fresh names" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeAll(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<[Base.RowDecoder._Wrapped?]>
    {
        return base.observationForAll().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeAll(on:in:startImmediately:)")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder._Wrapped?]>
    {
        return observeAll(on: scheduler, in: reader, startImmediately: startImmediately)
    }

    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<String?>(sql: "SELECT name FROM player ORDER BY score DESC")
    ///     request.rx
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (name: String?) in
    ///             print("Fresh name: \(name)")
    ///         })
    ///
    /// All elements are emitted on the main queue by default, unless you
    /// provide a specific `scheduler`.
    ///
    /// If you set `startImmediately` to true (the default value), the first
    /// element is emitted immediately, from the current database state.
    /// Furthermore, this first element is emitted *synchronously* if and only
    /// if the observable is subscribed on the main queue, and is given a nil
    /// `scheduler` argument:
    ///
    ///     // on the main queue
    ///     request.rx
    ///         .observeFirst(in: dbQueue)
    ///         .subscribe(onNext: { (name: String?) in
    ///             // on the main queue
    ///             print("Fresh name: \(name)")
    ///         })
    ///     // <- here "Fresh name" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observeFirst(
        on scheduler: ImmediateSchedulerType? = nil,
        in reader: DatabaseReader,
        startImmediately: Bool = true)
        -> Observable<Base.RowDecoder._Wrapped?>
    {
        return base.observationForFirst().rx.observe(
            on: scheduler,
            in: reader,
            startImmediately: startImmediately)
    }
    
    @available(*, deprecated, renamed: "observeFirst(on:in:startImmediately:)")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder._Wrapped?>
    {
        return observeFirst(on: scheduler, in: reader, startImmediately: startImmediately)
    }
}
