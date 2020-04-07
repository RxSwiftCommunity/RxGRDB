import GRDB
import RxSwift

/// We want the `rx` joiner on DatabaseWriter.
/// Normally we'd use ReactiveCompatible. But ReactiveCompatible is unable to
/// define `rx` on existentials as well:
///
///     let writer: DatabaseWriter
///     writer.rx...
///
/// :nodoc:
extension DatabaseWriter {
    public var rx: Reactive<AnyDatabaseWriter> {
        Reactive(AnyDatabaseWriter(self))
    }
}

extension Reactive where Base: DatabaseWriter {
    /// Returns an Observable that asynchronously writes into the database.
    ///
    /// For example:
    ///
    ///     // Observable<Int>
    ///     let newPlayerCount = dbQueue.rx.flatMapWrite { db in
    ///         try Player(...).insert(db)
    ///         let newPlayerCount = try Player.fetchAll(db)
    ///         return Observable.just(newPlayerCount)
    ///     }
    ///
    /// The database updates are executed inside a database transaction. If the
    /// transaction completes successfully, the observable returned from the
    /// closure is subscribed, from a database protected dispatch queue,
    /// immediately after the transaction has been committed.
    ///
    /// - parameter scheduler: The scheduler on which the observable completes.
    ///   Defaults to MainScheduler.instance.
    /// - parameter updates: A closure which writes in the database.
    func flatMapWrite<T>(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> Single<T>)
        -> Single<T>
    {
        Single
            .create(subscribe: { observer in
                var disposable: Disposable?
                self.base.asyncWriteWithoutTransaction { db in
                    var single: Single<T>?
                    do {
                        try db.inTransaction {
                            single = try updates(db)
                            return .commit
                        }
                        // Subscribe after transaction
                        disposable = single!.subscribe(observer)
                    } catch {
                        observer(.error(error))
                    }
                }
                return Disposables.create {
                    disposable?.dispose()
                }
            })
            .observeOn(scheduler)
    }
    
    /// Returns a Single that asynchronously writes into the database.
    ///
    ///     let newPlayerCount: Single<Int> = dbQueue.rx.write { db in
    ///         try Player(...).insert(db)
    ///         return try Player.fetchCount(db)
    ///     }
    ///
    /// By default, the single completes on the main dispatch queue. If
    /// you give a *scheduler*, is completes on that scheduler.
    ///
    /// - parameter scheduler: The scheduler on which the observable completes.
    ///   Defaults to MainScheduler.instance.
    /// - parameter updates: A closure which writes in the database.
    public func write<T>(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> T)
        -> Single<T>
    {
        flatMapWrite(
            observeOn: scheduler,
            updates: { db in try .just(updates(db)) })
    }
    
    /// Returns a Single that asynchronously writes into the database.
    ///
    ///     let newPlayerCount: Single<Int> = dbQueue.rx.write(
    ///         updates: { db in try Player(...).insert(db) },
    ///         thenRead: { db, _ in try Player.fetchCount(db) })
    ///
    /// By default, the single completes on the main dispatch queue. If
    /// you give a *scheduler*, is completes on that scheduler.
    ///
    /// - parameter scheduler: The scheduler on which the observable completes.
    ///   Defaults to MainScheduler.instance.
    /// - parameter updates: A closure which writes in the database.
    /// - parameter value: A closure which reads from the database.
    public func write<T, U>(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> T,
        thenRead value: @escaping (Database, T) throws -> U)
        -> Single<U>
    {
        flatMapWrite(
            observeOn: scheduler,
            updates: { db in
                let updatesValue = try updates(db)
                return Single.create { observer in
                    self.base.spawnConcurrentRead { db in
                        do {
                            try observer(.success(value(db.get(), updatesValue)))
                        } catch {
                            observer(.error(error))
                        }
                    }
                    return Disposables.create { }
                }
        })
    }
}
