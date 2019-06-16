import GRDB
import RxSwift

extension AnyDatabaseWriter: ReactiveCompatible { }

extension Reactive where Base: DatabaseWriter {
    /// Returns a Completable that asynchronously writes into the database.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let completable: Completable = dbQueue.rx.write { db in
    ///         try Player.fetchAll(db)
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
        let writer = base
        return Completable
            .create { observer in
                writer.asyncWrite(updates, completion: { (_, result) in
                    switch result {
                    case .success:
                        observer(.completed)
                    case let .failure(error):
                        observer(.error(error))
                    }
                })
                return Disposables.create { }
            }
            .observeOn(scheduler)
    }
    
    /// Returns a Single that asynchronously writes into the database.
    ///
    ///     let newPlayerCount: Single<Int> = dbQueue.rx.write { db in
    ///         try Player.fetchAll(db)
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
        let writer = base
        return Single
            .create { observer in
                writer.asyncWrite(updates, completion: { (_, result) in
                    do {
                        try observer(.success(result.get()))
                    } catch {
                        observer(.error(error))
                    }
                })
                return Disposables.create { }
            }
            .observeOn(scheduler)
    }
}
