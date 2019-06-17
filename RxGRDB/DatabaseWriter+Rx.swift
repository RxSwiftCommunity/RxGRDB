import GRDB
import RxSwift

extension AnyDatabaseWriter: ReactiveCompatible { }

extension Reactive where Base: DatabaseWriter {
    /// Returns an Observable that asynchronously writes into the database.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let newPlayerCount: Observable<Int> = dbQueue.rx.flatMapWrite { db in
    ///         try Player(...).insert(db)
    ///         let newPlayerCount = try Player.fetchAll(db)
    ///         return Observable.just(newPlayerCount)
    ///     }
    ///
    /// - parameter updates: A closure which writes in the database and returns
    ///   an Observable.
    public func flatMapWrite<T>(updates: @escaping (Database) throws -> Observable<T>) -> Observable<T> {
        let writer = base
        return Observable.create { observer in
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
    }
    
    /// Returns a Single that asynchronously writes into the database.
    ///
    ///     let dbPool = DatabasePool()
    ///     let newPlayerCount: Single<Int> = dbQueue.rx.flatMapWrite { db in
    ///         try Player(...).insert(db)
    ///         return dbPool.rx.concurrentRead { db in
    ///             try Player.fetchAll(db)
    ///         }
    ///     }
    ///
    /// - parameter updates: A closure which writes in the database and returns
    ///   a Single.
    public func flatMapWrite<T>(updates: @escaping (Database) throws -> Single<T>) -> Single<T> {
        return flatMapWrite { try updates($0).asObservable() }.asSingle()
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
    /// - parameter updates: A closure which writes in the database.
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func writeCompletable(
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance,
        updates: @escaping (Database) throws -> Void)
        -> Completable
    {
        return flatMapWrite(updates: { db in
            do {
                try updates(db)
                return .empty()
            } catch {
                return .error(error)
            }
        }).asCompletable().observeOn(scheduler)
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
    /// - parameter updates: A closure which writes in the database.
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func write<T>(
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance,
        updates: @escaping (Database) throws -> T)
        -> Single<T>
    {
        return flatMapWrite(updates: { db in
            do {
                return try .just(updates(db))
            } catch {
                return .error(error)
            }
        }).asSingle().observeOn(scheduler)
    }
}

extension Reactive where Base == DatabasePool {
    /// Returns a Single that asynchronously emits the fetched value.
    ///
    /// This Single must be subscribed from a writing database dispatch queue,
    /// outside of any transaction. You'll get a fatal error otherwise.
    ///
    /// You can for example use it with `flatMapWrite`:
    ///
    ///     let dbPool = DatabasePool()
    ///     let newPlayerCount: Single<Int> = dbQueue.rx.flatMapWrite { db in
    ///         try Player(...).insert(db)
    ///         return dbPool.rx.concurrentRead { db in
    ///             try Player.fetchAll(db)
    ///         }
    ///     }
    ///
    /// By default, returned values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter value: A closure which accesses the database.
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func concurrentRead<T>(
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance,
        value: @escaping (Database) throws -> T)
        -> Single<T>
    {
        let writer = base
        return Single
            .create { observer in
                writer.asyncConcurrentRead { db in
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
