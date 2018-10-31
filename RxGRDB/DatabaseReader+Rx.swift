//#if USING_SQLCIPHER
//    import GRDBCipher
//#else
//    import GRDB
//#endif
//import RxSwift
//
//extension Reactive where Base: DatabaseReader {
//    /// Returns an Observable that emits values after each committed
//    /// database transaction that has modified the tables, columns,
//    /// and rows defined by some *regions*.
//    ///
//    ///     // When the players table is changed, fetch the ten best ones,
//    ///     // as well as the total number of players:
//    ///     dbQueue.rx
//    ///         .fetch(from: [Player.all()]) { (db: Database) -> ([Player], Int) in
//    ///             let players = try Player.order(scoreColumn.desc).limit(10).fetchAll(db)
//    ///             let count = try Player.fetchCount(db)
//    ///             return (players, count)
//    ///         }
//    ///         .subscribe(onNext: { (players, count) in
//    ///             print("Best players out of \(count): \(players)")
//    ///         })
//    ///
//    /// The `values` closure argument is called after each impactful
//    /// transaction, and returns the values emitted by the observable. It runs
//    /// in a protected database queue.
//    ///
//    /// By default, all values are emitted on the main dispatch queue. If you
//    /// give a *scheduler*, values are emitted on that scheduler.
//    ///
//    /// If you set *startImmediately* to true (the default value), the first
//    /// element is emitted right upon subscription. It is *synchronously*
//    /// emitted if and only if the observable is subscribed on the main queue,
//    /// and is given a nil *scheduler* argument:
//    ///
//    ///     // on the main queue
//    ///     dbQueue.rx
//    ///         .fetch(from: [request, ...]) { db in ... }
//    ///         .subscribe(onNext: { values in
//    ///             // on the main queue
//    ///             print("Values have changed")
//    ///         })
//    ///     // <- here "Values have changed" has been printed
//    ///
//    ///     // on any queue
//    ///     request.rx
//    ///         .fetch(from: [request, ...], scheduler: MainScheduler.instance) { db in ... }
//    ///         .subscribe(onNext: { values in
//    ///             // on the main queue
//    ///             print("Values have changed")
//    ///         })
//    ///     // <- here "Values have changed" may not be printed yet
//    ///
//    /// - parameter regions: The observed regions.
//    /// - parameter startImmediately: When true (the default), the first
//    ///   element is emitted right upon subscription.
//    /// - parameter scheduler: The eventual scheduler on which elements
//    ///   are emitted.
//    /// - parameter values: A closure that returns the values emitted by
//    ///   the observable
//    public func fetch<T>(
//        from regions: [DatabaseRegionConvertible],
//        startImmediately: Bool = true,
//        scheduler: ImmediateSchedulerType? = nil,
//        values: @escaping (Database) throws -> T)
//        -> Observable<T>
//    {
//        let region = AnyDatabaseRegionConvertible { db in
//            try regions.reduce(into: DatabaseRegion()) {
//                try $0.formUnion($1.databaseRegion(db))
//            }
//        }
//        return ValueObservation.tracking(region, fetch: values).rx.fetch(
//            in: base,
//            startImmediately: startImmediately,
//            scheduler: scheduler)
//    }
//}
