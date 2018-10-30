#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

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
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changes(
        in writer: DatabaseWriter,
        startImmediately: Bool = true)
        -> Observable<Database>
    {
        return AnyDatabaseWriter(writer).rx.changes(
            in: [base],
            startImmediately: startImmediately)
    }
}

extension Reactive where Base: DatabaseWriter {
    /// Returns an Observable that emits a database connection after each
    /// committed database transaction that has modified the tables, columns,
    /// and rows defined by the *regions*.
    ///
    /// All elements are emitted in a protected database dispatch queue,
    /// serialized with all database updates. If you set *startImmediately* to
    /// true (the default value), the first element is emitted synchronously
    /// upon subscription. See [GRDB Concurrency Guide](https://github.com/groue/GRDB.swift/blob/master/README.md#concurrency)
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
    /// - parameter regions: The observed regions.
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    public func changes(
        in regions: [DatabaseRegionConvertible],
        startImmediately: Bool = true)
        -> Observable<Database>
    {
        return ChangesObservable(
            writer: base,
            startImmediately: startImmediately,
            observedRegion: { db in try regions.map { try $0.databaseRegion(db) }.union() })
            .asObservable()
    }
}

extension Reactive where Base: DatabaseReader {
    /// Returns an Observable that emits values after each committed
    /// database transaction that has modified the tables, columns,
    /// and rows defined by some *regions*.
    ///
    ///     // When the players table is changed, fetch the ten best ones,
    ///     // as well as the total number of players:
    ///     dbQueue.rx
    ///         .fetch(from: [Player.all()]) { (db: Database) -> ([Player], Int) in
    ///             let players = try Player.order(scoreColumn.desc).limit(10).fetchAll(db)
    ///             let count = try Player.fetchCount(db)
    ///             return (players, count)
    ///         }
    ///         .subscribe(onNext: { (players, count) in
    ///             print("Best players out of \(count): \(players)")
    ///         })
    ///
    /// The `values` closure argument is called after each impactful
    /// transaction, and returns the values emitted by the observable. It runs
    /// in a protected database queue.
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
    ///     dbQueue.rx
    ///         .fetch(from: [request, ...]) { db in ... }
    ///         .subscribe(onNext: { values in
    ///             // on the main queue
    ///             print("Values have changed")
    ///         })
    ///     // <- here "Values have changed" has been printed
    ///
    ///     // on any queue
    ///     request.rx
    ///         .fetch(from: [request, ...], scheduler: MainScheduler.instance) { db in ... }
    ///         .subscribe(onNext: { values in
    ///             // on the main queue
    ///             print("Values have changed")
    ///         })
    ///     // <- here "Values have changed" may not be printed yet
    ///
    /// - parameter regions: The observed regions.
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    /// - parameter values: A closure that returns the values emitted by
    ///   the observable
    public func fetch<T>(
        from regions: [DatabaseRegionConvertible],
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil,
        values: @escaping (Database) throws -> T)
        -> Observable<T>
    {
        let region = AnyDatabaseRegionConvertible { db in
            try regions.reduce(into: DatabaseRegion()) {
                try $0.formUnion($1.databaseRegion(db))
            }
        }
        return ValueObservation
            .tracking(region, fetch: values)
            .rx
            .start(
                in: base,
                startImmediately: startImmediately,
                scheduler: scheduler)
    }
}

/// TODO: remove
extension Array where Element == DatabaseRegion {
    func union() -> DatabaseRegion {
        if let initial = first {
            return suffix(from: 1).reduce(into: initial) { $0.formUnion($1) }
        } else {
            return DatabaseRegion()
        }
    }
}

private class ChangesObservable : ObservableType {
    typealias E = Database
    let writer: DatabaseWriter
    let startImmediately: Bool
    let observedRegion: (Database) throws -> DatabaseRegion
    
    /// Creates an observable that emits writer database connections on their
    /// dedicated dispatch queue when a transaction has modified the database
    /// in a way that impacts some requests' selections.
    ///
    /// When the `startImmediately` argument is true, the observable also emits
    /// a database connection, synchronously.
    init(
        writer: DatabaseWriter,
        startImmediately: Bool,
        observedRegion: @escaping (Database) throws -> DatabaseRegion)
    {
        self.writer = writer
        self.startImmediately = startImmediately
        self.observedRegion = observedRegion
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == Database {
        do {
            let writer = self.writer
            
            let transactionObserver = try writer.unsafeReentrantWrite { db -> DatabaseRegionObserver in
                if startImmediately {
                    observer.onNext(db)
                }
                
                let transactionObserver = try DatabaseRegionObserver(
                    observedRegion: observedRegion(db),
                    onChange: { observer.onNext(db) })
                db.add(transactionObserver: transactionObserver)
                return transactionObserver
            }
            
            return Disposables.create {
                writer.unsafeReentrantWrite { db in
                    db.remove(transactionObserver: transactionObserver)
                }
            }
        } catch {
            observer.onError(error)
            return Disposables.create()
        }
    }
}

private class DatabaseRegionObserver : TransactionObserver {
    var changed: Bool = false
    let observedRegion: DatabaseRegion
    let change: () -> Void
    
    init(observedRegion: DatabaseRegion, onChange change: @escaping () -> Void) {
        self.observedRegion = observedRegion
        self.change = change
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return observedRegion.isModified(byEventsOfKind:eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if observedRegion.isModified(by: event) {
            changed = true
            stopObservingDatabaseChangesUntilNextTransaction()
        }
    }
    
    func databaseWillCommit() { }
    
    func databaseDidCommit(_ db: Database) {
        // Avoid reentrancy bugs
        let changed = self.changed
        self.changed = false
        if changed {
            change()
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        changed = false
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    func databaseWillChange(with event: DatabasePreUpdateEvent) { }
    #endif
}
