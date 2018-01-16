#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension Reactive where Base: DatabaseWriter {
    /// Returns an Observable that emits a database connection after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the requests.
    ///
    /// All elements are emitted in a protected database dispatch queue,
    /// serialized with all database updates. If you set *startImmediately* to
    /// true (the default value), the first element is emitted right upon
    /// subscription. See [GRDB Concurrency Guide](https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency)
    /// for more information.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     try dbQueue.inDatabase { db in
    ///         try db.create(table: "persons") { t in
    ///             t.column("id", .integer).primaryKey()
    ///             t.column("name", .text)
    ///         }
    ///     }
    ///
    ///     let request = SQLRequest("SELECT * FROM persons")
    ///     dbQueue.changes(in: [request])
    ///         .subscribe(onNext: { db in
    ///             let count = try! request.fetchCount(db)
    ///             print("Number of persons: \(count)")
    ///         })
    ///     // Prints "Number of persons: 0"
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    ///         // Prints "Number of persons: 1"
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
    ///         // Prints "Number of persons: 2"
    ///     }
    ///
    ///     try dbQueue.inTransaction { db in
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Craig"])
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["David"])
    ///         return .commit
    ///     }
    ///     // Prints "Number of persons: 4"
    ///
    /// - parameter requests: The observed requests.
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changes(
        in requests: [Request],
        startImmediately: Bool = true)
        -> Observable<Database>
    {
        return SelectionInfoDatabaseObservable(
            writer: base,
            startImmediately: startImmediately,
            selectionInfos: { db in try requests.map { try $0.selectionInfo(db) } })
            .asObservable()
    }
    
    /// Returns an Observable that emits a change token after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the requests.
    ///
    /// The change tokens are meant to be used by the mapFetch operator:
    ///
    ///     // When the players table is changed, fetch the ten best ones, as well as the
    ///     // total number of players:
    ///     dbQueue.rx
    ///         .changeTokens(in: [Player.all()])
    ///         .mapFetch { (db: Database) -> ([Player], Int) in
    ///             let players = try Player.order(scoreColumn.desc).limit(10).fetchAll(db)
    ///             let count = try Player.fetchCount(db)
    ///             return (players, count)
    ///         }
    ///         .subscribe(onNext: { (players, count) in
    ///             print("Best players out of \(count): \(players)")
    ///         })
    ///
    /// All values from the mapFetch operator are emitted on *scheduler*, which
    /// defaults to `MainScheduler.instance`. If you set *startImmediately* to
    /// true (the default value), the first element is emitted right
    /// upon subscription.
    ///
    /// - parameter requests: The observed requests.
    /// - parameter startImmediately: When true (the default), mapFetch emits
    ///   its first right upon subscription.
    /// - parameter scheduler: The scheduler on which mapFetch emits its
    ///   elements (default is MainScheduler.instance).
    public func changeTokens(
        in requests: [Request],
        startImmediately: Bool = true,
        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance)
        -> Observable<ChangeToken>
    {
        return SelectionInfoChangeTokensObservable(
            writer: base,
            startImmediately: startImmediately,
            scheduler: scheduler,
            selectionInfos: { db in try requests.map { try $0.selectionInfo(db) } })
            .asObservable()
    }
}
