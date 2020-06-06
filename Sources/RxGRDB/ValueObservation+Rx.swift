import GRDB
import RxSwift

extension ValueObservation: ReactiveCompatible { }

/// :nodoc:
public protocol _ValueObservationProtocol: ReactiveCompatible {
    associatedtype Reducer: _ValueReducer
    func start(
        in reader: DatabaseReader,
        scheduling scheduler: ValueObservationScheduler,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void) -> DatabaseCancellable
}

/// :nodoc:
extension ValueObservation: _ValueObservationProtocol { }

extension Reactive where Base: _ValueObservationProtocol {
    /// Creates an Observable which tracks changes in database values.
    ///
    /// For example:
    ///
    ///     let observation = ValueObservation.tracking { db in
    ///         try Player.fetchAll(db)
    ///     }
    ///     let disposable = observation.rx
    ///         .observe(in: dbQueue)
    ///         .subscribe(
    ///             onNext: { players: [Player] in
    ///                 print("fresh players: \(players)")
    ///             },
    ///             onError: { error in ... })
    ///
    /// By default, fresh values are dispatched asynchronously on the
    /// main queue. You can change this behavior by by providing a scheduler.
    ///
    /// For example, `.immediate` notifies all values on the main queue as well,
    /// and the first one is immediately notified when the observable
    /// is subscribed:
    ///
    ///     // on the main queue
    ///     observation.rx
    ///         .observe(
    ///             in: dbQueue,
    ///             scheduling: .immediate) // <-
    ///         .subscribe(onNext: { (players: [Player]) in
    ///             // on the main queue
    ///             print("Fresh players: \(players)")
    ///         })
    ///     // <- here "Fresh players" has been printed
    ///
    /// Note that the `.immediate` scheduler requires that the observable is
    /// subscribed from the main thread. It raises a fatal error otherwise.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    ///   are emitted.
    /// - parameter scheduler: A Scheduler. By default, fresh values are
    ///   dispatched asynchronously on the main queue.
    /// - returns: An Observable of fresh values.
    public func observe(
        in reader: DatabaseReader,
        scheduling scheduler: ValueObservationScheduler = .async(onQueue: .main))
        -> Observable<Base.Reducer.Value>
    {
        Observable.create { [weak reader] observer in
            guard let reader = reader else {
                return Disposables.create()
            }
            
            let cancellable = self.base.start(
                in: reader,
                scheduling: scheduler,
                onError: observer.onError,
                onChange: observer.onNext)
            return Disposables.create(with: cancellable.cancel)
        }
    }
}
