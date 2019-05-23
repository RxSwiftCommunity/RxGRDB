import GRDB
import RxSwift

extension AdaptedFetchRequest: ReactiveCompatible { }
extension AnyFetchRequest: ReactiveCompatible { }
extension QueryInterfaceRequest: ReactiveCompatible { }
extension SQLRequest: ReactiveCompatible { }

extension Reactive where Base: DatabaseRegionConvertible {
    /// Returns an Observable that emits a database connection after each
    /// committed database transaction that has modified the tables and columns
    /// fetched by the request.
    ///
    /// All elements are emitted in a protected database dispatch queue,
    /// serialized with all database updates. If you set *startImmediately* to
    /// true (the default value), the first element is emitted synchronously
    /// upon subscription. See [GRDB Concurrency Guide](https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency)
    /// for more information.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     try dbQueue.write { db in
    ///         try db.create(table: "player") { t in
    ///             t.column("id", .integer).primaryKey()
    ///             t.column("name", .text)
    ///         }
    ///     }
    ///
    ///     struct Player: Encodable, PersistableRecord {
    ///         var id: Int64
    ///         var name: String
    ///     }
    ///
    ///     let request = Player.all()
    ///     request.rx
    ///         .changes(in: dbQueue)
    ///         .subscribe(onNext: { db in
    ///             let count = try! Player.fetchCount(db)
    ///             print("Number of players: \(count)")
    ///         })
    ///     // Prints "Number of players: 0"
    ///
    ///     try dbQueue.write { db in
    ///         try Player(id: 1, name: "Arthur").insert(db)
    ///         try Player(id: 2, name: "Barbara").insert(db)
    ///     }
    ///     // Prints "Number of players: 2"
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try Player(id: 3, name: "Craig").insert(db)
    ///         // Prints "Number of players: 3"
    ///         try Player(id: 4, name: "David").insert(db)
    ///         // Prints "Number of players: 4"
    ///     }
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changes(
        in writer: DatabaseWriter,
        startImmediately: Bool = true)
        -> Observable<Database>
    {
        return DatabaseRegionObservation(tracking: base)
            .rx
            .changes(in: writer, startImmediately: startImmediately)
    }
}
