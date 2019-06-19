import GRDB
import RxSwift

extension AnyDatabaseWriter: ReactiveCompatible { }

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
    public func flatMapWrite<T>(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> Observable<T>)
        -> Observable<T>
    {
        let writer = base
        return Observable
            .create { observer in
                var disposable: Disposable?
                writer.asyncWriteWithoutTransaction { db in
                    var observable: Observable<T>?
                    do {
                        try db.inTransaction {
                            observable = try updates(db)
                            return .commit
                        }
                        // Subscribe after transaction
                        disposable = observable!.subscribe(observer)
                    } catch {
                        observer.onError(error)
                    }
                }
                return Disposables.create {
                    disposable?.dispose()
                }
            }
            .observeOn(scheduler)
    }
    
    /// Returns a Single that asynchronously writes into the database.
    ///
    /// For example:
    ///
    ///     // Single<Int>
    ///     let newPlayerCount = dbQueue.rx.flatMapWrite { db -> Single<Int> in
    ///         try Player(...).insert(db)
    ///         let count = try Player.fetchCount(db)
    ///         return Single.just(count)
    ///     }
    ///
    /// The database updates are executed inside a database transaction. If the
    /// transaction completes successfully, the single returned from the closure
    /// is subscribed, from a database protected dispatch queue, immediately
    /// after the transaction has been committed.
    ///
    /// When you use a Database Pool, and your app executes some database
    /// updates followed by some fetches, you can wrap `concurrentRead` inside
    /// `flatMapWrite` in order to profit from optimized database scheduling.
    /// For example:
    ///
    ///     // Single<Int>
    ///     let newPlayerCount = dbPool.rx
    ///         .flatMapWrite { db in
    ///             // Write: delete all players
    ///             try Player.deleteAll(db)
    ///
    ///             return dbPool.rx.concurrentRead { db in
    ///                 // Read: the count is guaranteed to be zero
    ///                 try Player.fetchCount(db)
    ///             }
    ///         }
    ///
    /// The optimization guarantees that the concurrent read does not block any
    /// concurrent write, and yet sees the database in the state left by the
    /// completed transaction.
    ///
    /// When you use a Database Queue, the observable returned by a
    /// `concurrentRead` wrapped into `flatMapWrite` emits exactly the same
    /// values, but the scheduling optimization is not applied.
    ///
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.instance.
    /// - parameter updates: A closure which writes in the database.
    public func flatMapWrite<T>(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> Single<T>)
        -> Single<T>
    {
        return flatMapWrite(
            observeOn: scheduler,
            updates: { try updates($0).asObservable() })
            .asSingle()
    }
    
    /// Returns a Completable that asynchronously writes into the database.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let completable: Completable = dbQueue.rx.write { db in
    ///         try Player(...).insert(db)
    ///     }
    ///
    /// By default, the completable completes on the main dispatch queue. If
    /// you give a *scheduler*, is completes on that scheduler.
    ///
    /// - parameter scheduler: The scheduler on which the completable completes.
    ///   Defaults to MainScheduler.instance.
    /// - parameter updates: A closure which writes in the database.
    public func writeCompletable(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> Void)
        -> Completable
    {
        return flatMapWrite(
            observeOn: scheduler,
            updates: { db in
                do {
                    try updates(db)
                    return .empty()
                } catch {
                    return .error(error)
                }
        })
            .asCompletable()
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
        return flatMapWrite(
            observeOn: scheduler,
            updates: { db in
                do {
                    return try .just(updates(db))
                } catch {
                    return .error(error)
                }
        })
            .asSingle()
    }
    
    /// Returns a Single that asynchronously emits the fetched value.
    ///
    /// The Single must be subscribed from a writing database dispatch queue,
    /// outside of any transaction. You'll get a fatal error otherwise.
    ///
    /// It completes on some unspecified queue.
    ///
    /// You can for example use it with `flatMapWrite`:
    ///
    ///     let dbPool = DatabasePool()
    ///     let newPlayerCount: Single<Int> = dbPool.rx
    ///         .flatMapWrite { db in
    ///             try Player(...).insert(db)
    ///             return dbPool.rx.concurrentRead { db in
    ///                 try Player.fetchAll(db)
    ///             }
    ///         }
    ///
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.instance.
    /// - parameter value: A closure which accesses the database.
    public func concurrentRead<T>(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        value: @escaping (Database) throws -> T)
        -> Single<T>
    {
        let writer = base
        return Single
            .create { observer in
            writer.spawnConcurrentRead { db in
                do {
                    try observer(.success(value(db.get())))
                } catch {
                    observer(.error(error))
                }
            }
            return Disposables.create { }
        }
            .observeOn(scheduler)
    }
}
