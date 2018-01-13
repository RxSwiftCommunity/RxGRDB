#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension Reactive where Base: Request {
    /// Returns an Observable that emits a database connection after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first element
    /// is emitted synchronously, on subscription.
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
    ///     request.rx
    ///         .changes(in: dbQueue)
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
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changes(
        in writer: DatabaseWriter,
        synchronizedStart: Bool = true)
        -> Observable<Database>
    {
        return AnyDatabaseWriter(writer).rx.changes(
            in: [base],
            synchronizedStart: synchronizedStart)
    }
    
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// All values are emitted on *scheduler*, which defaults to
    /// `MainScheduler.instance`. If you set *synchronizedStart* to true (the
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
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter scheduler: The scheduler on which elements are emitted
    ///   (default is MainScheduler.instance).
    public func fetchCount(
        in writer: DatabaseWriter,
        synchronizedStart: Bool = true,
        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance)
        -> Observable<Int>
    {
        let request = base
        return AnyDatabaseWriter(writer).rx
            .changeTokens(in: [request], synchronizedStart: synchronizedStart, scheduler: scheduler)
            .mapFetch { try request.fetchCount($0) }
    }
}
