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
    // Dependency on an experimental GRDB API
    func fetch(_ db: Database) throws -> _Reducer.Value?
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
    /// By default, all values are emitted on the main dispatch queue. If you
    /// give a *scheduler*, values are emitted on that scheduler.
    ///
    /// If you set *startImmediately* to true (the default value), the first
    /// element is emitted right upon subscription. It is *synchronously*
    /// emitted if and only if the observable is subscribed on the main queue,
    /// and is given a nil *scheduler* argument:
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
    ///     // on any queue
    ///     observation.rx
    ///         .observe(in: dbQueue)
    ///         .subscribe(onNext: { (players: [Player]) in
    ///             // on the main queue
    ///             print("Fresh players: \(players)")
    ///         })
    ///     // <- here "Fresh players" may not be printed yet
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func observe(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
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
}
    
extension Reactive where Base: _ValueObservationProtocol, Base._Reducer: ImmediateValueReducer {
    /// Returns a Single that eventually emits the first value emitted by
    /// the ValueObservation.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let observation = ValueObservation.trackingAll(Player.all())
    ///     observation.rx
    ///         .fetch(in: dbQueue)
    ///         .subscribe(onSuccess: { (players: [Player]) in
    ///             print("players: \(players)")
    ///         })
    ///
    /// By default, fetched values are emitted on the main dispatch queue. If
    /// you give a *scheduler*, values are emitted on that scheduler.
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted. Defaults to MainScheduler.asyncInstance.
    public func fetch(
        in reader: DatabaseReader,
        scheduler: ImmediateSchedulerType = MainScheduler.asyncInstance)
        -> Single<Base._Reducer.Value>
    {
        let observation = base
        return AnyDatabaseReader(reader).rx.fetch(scheduler: scheduler) { db in
            guard let value = try observation.fetch(db) else {
                fatalError("ImmediateSchedulerType contract broken: observation did not emit its first element")
            }
            return value
        }
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
