#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

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
