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
    /// Reactive extensions.
    public var rx: Reactive<AnyDatabaseWriter> {
        Reactive(AnyDatabaseWriter(self))
    }
}

extension Reactive where Base: DatabaseWriter {
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
        Single
            .create(subscribe: { observer in
                self.base.asyncWrite(updates, completion: { _, result in
                    switch result {
                    case let .success(value):
                        observer(.success(value))
                    case let .failure(error):
                        observer(.failure(error))
                    }
                })
                return Disposables.create()
            })
            // We don't want users to process emitted values on a
            // database dispatch queue.
            .observe(on: scheduler)
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
        Single
            .create(subscribe: { observer in
                self.base.asyncWriteWithoutTransaction { db in
                    var updatesValue: T?
                    do {
                        try db.inTransaction {
                            updatesValue = try updates(db)
                            return .commit
                        }
                    } catch {
                        observer(.failure(error))
                        return
                    }
                    self.base.spawnConcurrentRead { dbResult in
                        do {
                            try observer(.success(value(dbResult.get(), updatesValue!)))
                        } catch {
                            observer(.failure(error))
                        }
                    }
                }
                return Disposables.create()
            })
            // We don't want users to process emitted values on a
            // database dispatch queue.
            .observe(on: scheduler)
    }
}
