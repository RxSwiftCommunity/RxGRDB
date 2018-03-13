#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension Reactive where Base: SelectStatementRequest {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// All values are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *startImmediately* to true (the
    /// default value), the first element is emitted right upon subscription.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Person.all()
    ///     request.rx
    ///         .fetchCount(in: dbQueue)
    ///         .subscribe(onNext: { count in
    ///             print("Number of persons: \(count)")
    ///         })
    ///     // Prints "Number of persons: 0"
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try Person(name: "Arthur").insert(db)
    ///         // Prints "Number of persons: 1"
    ///         try Person(name: "Barbara").insert(db)
    ///         // Prints "Number of persons: 2"
    ///     }
    ///
    ///     try dbQueue.inTransaction { db in
    ///         try Person(name: "Craig").insert(db)
    ///         try Person(name: "David").insert(db)
    ///         return .commit
    ///     }
    ///     // Prints "Number of persons: 4"
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchCount(
        in writer: DatabaseWriter,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType = MainScheduler.instance)
        -> Observable<Int>
    {
        let request = base
        return AnyDatabaseWriter(writer).rx
            .fetchTokens(in: [request], startImmediately: startImmediately, scheduler: scheduler)
            .mapFetch { try request.fetchCount($0) }
    }
}
