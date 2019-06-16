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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Int>
    {
        return base.observationForCount().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
    
    /// Returns a Single that asynchronously emits the number of results in
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.all()
    ///     let count: Single<Int> = request.rx.fetchCount(in: dbQueue)
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchCount(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<Int>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchCount)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    {
        return base.observationForAll().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    {
        return base.observationForFirst().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
    
    /// Returns a Single that asynchronously emits all records fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.all()
    ///     let players: Single<[Player]> = request.rx.fetchAll(in: dbQueue)
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchAll(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<[Base.RowDecoder]>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchAll)
    }
    
    /// Returns a Single that asynchronously emits the first record fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.filter(key: 1)
    ///     let player = Single<Player?> = request.rx.fetchOne(in: dbQueue)
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchOne(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<Base.RowDecoder?>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchOne)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Row]>
    {
        return base.observationForAll().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Row?>
    {
        return base.observationForFirst().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
    
    /// Returns a Single that asynchronously emits all rows fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player")
    ///     let rows: Single<[Row]> = request.rx.fetchAll(in: dbQueue)
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchAll(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<[Row]>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchAll)
    }
    
    /// Returns a Single that asynchronously emits the first row fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<Row>(sql: "SELECT * FROM player WHERE id = 1")
    ///     let row: Single<Row?> = request.rx.fetchOne(in: dbQueue)
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchOne(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<Row?>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchOne)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    {
        return base.observationForAll().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    {
        return base.observationForFirst().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
    
    /// Returns a Single that asynchronously emits all values fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.select(Column("name"), as: String.self)
    ///     let names: Single<[String]> = request.rx.fetchAll(in: dbQueue)
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchAll(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<[Base.RowDecoder]>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchAll)
    }
    
    /// Returns a Single that asynchronously emits the first value fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<String>(sql: "SELECT name FROM player ORDER BY score DESC")
    ///     let bestPlayerName: Single<String?> = request.rx.fetchOne(in: dbQueue)
    ///
    /// The value is nil if the query returns no row, or if the fetched
    /// database value is null.
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchOne(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<Base.RowDecoder?>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchOne)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder._Wrapped?]>
    {
        return base.observationForAll().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
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
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder._Wrapped?>
    {
        return base.observationForFirst().rx.observe(
            in: reader,
            startImmediately: startImmediately,
            scheduler: scheduler)
    }
    
    /// Returns a Single that asynchronously emits all values fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Player.select(Column("name"), as: String.self)
    ///     let names: Single<[String?]> = request.rx.fetchAll(in: dbQueue)
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchAll(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<[Base.RowDecoder._Wrapped?]>
    {
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: base.fetchAll)
    }
    
    /// Returns a Single that asynchronously emits the first value fetched by
    /// the request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = SQLRequest<String?>(sql: "SELECT name FROM player ORDER BY score DESC")
    ///     let name: Single<String?>= request.rx.fetchOne(in: dbQueue)
    ///
    /// The value is nil if the query returns no row, or if the fetched
    /// database value is null.
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetchOne(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<Base.RowDecoder._Wrapped?>
    {
        let request = base
        return AnyDatabaseReader(reader).rx.fetch(
            scheduler: scheduler,
            value: { db in try Base.RowDecoder._Wrapped.fetchOne(db, request) })
    }
}
