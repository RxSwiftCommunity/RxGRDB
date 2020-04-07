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
    /// main queue. You can change this behavior by calling the `scheduling(_:)`
    /// method on the returned observable.
    ///
    /// For example, `scheduling(.immediate)` notifies all values on the main
    /// queue as well, and the first one is immediately notified when the
    /// publisher is subscribed:
    ///
    ///     let disposable = observation.rx
    ///         .observe(in: dbQueue)
    ///         .scheduling(.immediate) // <-
    ///         .subscribe(
    ///             onNext: { players: [Player] in
    ///                 print("fresh players: \(players)")
    ///             },
    ///             onError: { error in ... })
    ///     // <- here "fresh players" is already printed.
    ///
    /// - parameter reader: A DatabaseReader.
    /// - returns: A Combine publisher
    ///
    /// Returns an Observable that emits the same values as a ValueObservation.
    ///
    ///     let observation = ValueObservation.trackingAll(Player.all())
    ///     observation.rx
    ///         .observe(in: dbQueue)
    ///         .subscribe(onNext: { (players: [Player]) in
    ///             print("Fresh players: \(players)")
    ///         })
    ///
    /// All elements are emitted on the main queue by default, unless you
    /// provide a specific `scheduler`.
    ///
    /// If you set `startImmediately` to true (the default value), the first
    /// element is emitted immediately, from the current database state.
    /// Furthermore, this first element is emitted *synchronously* if and only
    /// if the observable is subscribed on the main queue, and is given a nil
    /// `scheduler` argument:
    ///
    ///     // on the main queue
    ///     observation.rx
    ///         .observe(in: dbQueue)
    ///         .subscribe(onNext: { (players: [Player]) in
    ///             // on the main queue
    ///             print("Fresh players: \(players)")
    ///         })
    ///     // <- here "Fresh players" has been printed
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    ///   are emitted.
    public func observe(in reader: DatabaseReader) -> ValueObservationObservable<Base.Reducer.Value> {
        ValueObservationObservable(base, in: reader)
    }
    
    @available(*, unavailable, message: "Use observe(in:) instead")
    public func observe(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> ValueObservationObservable<Base.Reducer.Value>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use observe(in:) instead")
    public func fetch(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> ValueObservationObservable<Base.Reducer.Value>
    { preconditionFailure() }
}

public struct ValueObservationObservable<Element>: ObservableType {
    private let start: Start<Element>
    private var scheduler = ValueObservationScheduler.async(onQueue: .main)
    
    init<Observation: _ValueObservationProtocol>(
        _ observation: Observation,
        in reader: DatabaseReader)
        where Observation.Reducer.Value == Element
    {
        start = { [weak reader] (scheduler, onError, onChange) in
            guard let reader = reader else {
                return AnyDatabaseCancellable(cancel: { })
            }
            return observation.start(in: reader, scheduling: scheduler, onError: onError, onChange: onChange)
        }
    }
    
    public func subscribe<Observer>(_ observer: Observer) -> Disposable
        where Observer: ObserverType, Element == Observer.Element
    {
        asObservable().subscribe(observer)
    }
    
    public func asObservable() -> Observable<Element> {
        Observable.create { observer in
            let cancellable = self.start(
                self.scheduler,
                observer.onError,
                observer.onNext)
            return Disposables.create(with: cancellable.cancel)
        }
    }

    /// Returns an Observable which starts the observation with the given
    /// ValueObservation scheduler.
    ///
    /// For example, `scheduling(.immediate)` notifies all values on the
    /// main queue, and the first one is immediately notified when the
    /// publisher is subscribed:
    ///
    ///     let disposable = observation.rx
    ///         .observe(in: dbQueue)
    ///         .scheduling(.immediate) // <-
    ///         .subscribe(
    ///             onNext: { players: [Player] in
    ///                 print("fresh players: \(players)")
    ///             },
    ///             onError: { error in ... })
    ///     // <- here "fresh players" is already printed.
    public func scheduling(_ scheduler: ValueObservationScheduler) -> Self {
        var observable = self
        observable.scheduler = scheduler
        return observable
    }
}

private typealias Start<T> = (
    _ scheduler: ValueObservationScheduler,
    _ onError: @escaping (Error) -> Void,
    _ onChange: @escaping (T) -> Void) -> DatabaseCancellable
