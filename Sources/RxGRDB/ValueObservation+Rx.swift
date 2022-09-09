import GRDB
import RxSwift

extension ValueObservation {
    /// Reactive extensions.
    public var rx: GRDBReactive<Self> { GRDBReactive(self) }
}

/// :nodoc:
public protocol _ValueObservationProtocol {
    associatedtype Reducer: _ValueReducer
    func _start(
        in reader: GRDB.DatabaseReader,
        scheduling scheduler: GRDB.ValueObservationScheduler,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (Reducer.Value) -> Void)
    -> GRDB.DatabaseCancellable
}

/// :nodoc:
extension ValueObservation: _ValueObservationProtocol where Reducer: ValueReducer {
    public func _start(in reader: GRDB.DatabaseReader, scheduling scheduler: GRDB.ValueObservationScheduler, onError: @escaping (Error) -> Void, onChange: @escaping (Reducer.Value) -> Void) -> GRDB.DatabaseCancellable {
        start(in: reader, scheduling: scheduler, onError: onError, onChange: onChange)
    }
}

extension GRDBReactive where Base: _ValueObservationProtocol {
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
        Observable.create { observer in
            let cancellable = self.base._start(
                in: reader,
                scheduling: scheduler,
                onError: observer.onError,
                onChange: observer.onNext)
            return Disposables.create(with: cancellable.cancel)
        }
    }
}
