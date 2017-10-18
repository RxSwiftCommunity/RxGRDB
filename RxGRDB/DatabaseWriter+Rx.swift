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
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changes(in requests: [Request], synchronizedStart: Bool = true) -> Observable<Database> {
        return changeTokens(in: requests, synchronizedStart: synchronizedStart)
            .map { changeToken -> Database? in
                switch changeToken.kind {
                case .databaseSubscription(let db): return db
                case .subscription: return nil
                case .change(_, let db): return db
                }
            }
            .filter { $0 != nil }
            .map { $0! }
    }
    
    /// Returns an Observable that emits a change token after each committed
    /// database transaction that has modified the tables and columns fetched by
    /// the requests.
    ///
    /// If you set `synchronizedStart` to true (the default), the first element
    /// is emitted synchronously, on subscription.
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
    /// - parameter requests: The observed requests.
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changeTokens(in requests: [Request], synchronizedStart: Bool = true) -> Observable<ChangeToken> {
        return SelectionInfoChangeTokensObservable(
            writer: base,
            synchronizedStart: synchronizedStart,
            selectionInfos: { db -> [SelectStatement.SelectionInfo] in
                try requests.map { request in
                    let (statement, _) = try request.prepare(db)
                    return statement.selectionInfo
                }
        }).asObservable()
    }
}
