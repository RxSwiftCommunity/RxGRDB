#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension Reactive where Base: DatabaseWriter {
    /// Returns a RequestChangesObservable that emits a database connection
    /// after each committed database transaction that has modified the tables
    /// and columns fetched by the requests.
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
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    public func changes(in requests: [Request], synchronizedStart: Bool = true) -> Observable<Database> {
        return changeTokens(in: requests, synchronizedStart: synchronizedStart).map { $0.database }
    }
    
    /// TODO
    public func changeTokens(in requests: [Request], synchronizedStart: Bool = true) -> Observable<ChangeToken> {
        let writer = base
        
        return ChangeTokensObserver.rx.observable(forTransactionsIn: writer) { (db, observer) in
            if synchronizedStart {
                observer.on(.next(ChangeToken(.initialSync(db))))
            }
            let selectionInfos: [SelectStatement.SelectionInfo] = try requests.map { request in
                let (statement, _) = try request.prepare(db)
                return statement.selectionInfo
            }
            return ChangeTokensObserver(writer: writer, selectionInfos: selectionInfos, observer: observer)
        }
    }
}
