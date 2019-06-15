import GRDB
import RxSwift

extension AnyDatabaseReader: ReactiveCompatible { }
extension DatabasePool: ReactiveCompatible { }
extension DatabaseQueue: ReactiveCompatible { }
extension DatabaseSnapshot: ReactiveCompatible { }

extension Reactive where Base: DatabaseReader {
    /// Returns a Single that asynchronously emits the fetched value.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let players: Single<[Player]> = dbQueue.rx.fetch { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter value: A closer which fetches database values.
    /// - parameter scheduler: The scheduler on which the single completes.
    ///   Defaults to MainScheduler.asyncInstance.
    public func fetch<T>(
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance,
        value: @escaping (Database) throws -> T)
        -> Single<T>
    {
        let reader = base
        return Single
            .create { observer in
                reader.asyncRead { db in
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
