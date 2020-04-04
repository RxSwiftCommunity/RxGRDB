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
        return Reactive(AnyDatabaseWriter(self))
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
    public func write(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> Void)
        -> Completable
    {
        return flatMapWrite(
            observeOn: scheduler,
            updates: { db in
                try updates(db)
                return .empty()
        })
            .asCompletable()
    }
    
    /// Returns a Single that asynchronously writes into the database.
    ///
    ///     let newPlayerCount: Single<Int> = dbQueue.rx.writeAndReturn { db in
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
    public func writeAndReturn<T>(
        observeOn scheduler: ImmediateSchedulerType = MainScheduler.instance,
        updates: @escaping (Database) throws -> T)
        -> Single<T>
    {
        return flatMapWrite(
            observeOn: scheduler,
            updates: { db in try .just(updates(db)) })
            .asSingle()
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
        return flatMapWrite(
            observeOn: scheduler,
            updates: { db in
                let updatesValue = try updates(db)
                return Observable.create { observer in
                    self.base.spawnConcurrentRead { db in
                        do {
                            try observer.onNext(value(db.get(), updatesValue))
                            observer.onCompleted()
                        } catch {
                            observer.onError(error)
                        }
                    }
                    return Disposables.create { }
                }
        })
            .asSingle()
    }
}
