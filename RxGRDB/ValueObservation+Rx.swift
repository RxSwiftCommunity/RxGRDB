import GRDB
import RxSwift

extension ValueObservation : ReactiveCompatible { }

/// :nodoc:
public protocol _ValueObservationProtocol: ReactiveCompatible {
    associatedtype _Reducer: ValueReducer
    var scheduling: ValueScheduling { get set }
    func start(
        in reader: DatabaseReader,
        onError: @escaping (Error) -> Void,
        onChange: @escaping (_Reducer.Value) -> Void) -> TransactionObserver
}

/// :nodoc:
extension ValueObservation: _ValueObservationProtocol where Reducer: ValueReducer {
    public typealias _Reducer = Reducer
}

extension Reactive where Base: _ValueObservationProtocol {
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
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observe(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base._Reducer.Value>
    {
        var observation = base
        
        if let scheduler = scheduler {
            // Honor the scheduler parameter.
            // Deal with unsafe GRDB scheduling: we can only
            // guarantee correct ordering of values if observation
            // starts on the same queue as the queue values are
            // dispatched on.
            observation.scheduling = .unsafe(startImmediately: startImmediately)
            return observation
                .makeObservable(in: reader)
                .subscribeOn(scheduler)
                .observeOn(scheduler)
            
        } else if case .mainQueue = observation.scheduling , startImmediately == false {
            // Honor the startImmediately parameter
            observation.scheduling = .async(onQueue: .main, startImmediately: false)
            return observation.makeObservable(in: reader)
            
        } else {
            // Honor observation scheduling
            return observation.makeObservable(in: reader)
        }
    }
    
    @available(*, deprecated, renamed: "observe(in:startImmediately:observeOn:)")
    public func fetch(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base._Reducer.Value>
    {
        return observe(in: reader, startImmediately: startImmediately, observeOn: scheduler)
    }
}

extension _ValueObservationProtocol {
    fileprivate func makeObservable(in reader: DatabaseReader) -> Observable<_Reducer.Value> {
        return Observable.create { observer -> Disposable in
            var transactionObserver: TransactionObserver? = nil
            // Avoid the "Variable 'transactionObserver' was written to, but never read" warning
            _ = transactionObserver
            
            transactionObserver = self.start(
                in: reader,
                onError: observer.onError,
                onChange: observer.onNext)
            
            return Disposables.create {
                transactionObserver = nil
            }
        }
    }
}
