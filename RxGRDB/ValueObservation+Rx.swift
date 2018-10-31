#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// :nodoc:
public protocol _ValueObservationProtocol: ReactiveCompatible {
    associatedtype _Reducer: ValueReducer
    var scheduling: ValueScheduling { get set }
    func start(
        in reader: DatabaseReader,
        onError: ((Error) -> Void)?,
        onChange: @escaping (_Reducer.Value) -> Void) throws -> TransactionObserver
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
    ///         .fetch(in: dbQueue)
    ///         .subscribe(onNext: { players: [Player] in
    ///             print("Players have changed")
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
    ///         .fetch(in: dbQueue)
    ///         .subscribe(onNext: { players: [Player] in
    ///             // on the main queue
    ///             print("Values have changed")
    ///         })
    ///     // <- here "Values have changed" has been printed
    ///
    ///     // on any queue
    ///     observation.rx
    ///         .fetch(in: dbQueue)
    ///         .subscribe(onNext: { players: [Player] in
    ///             // on the main queue
    ///             print("Values have changed")
    ///         })
    ///     // <- here "Values have changed" may not be printed yet
    ///
    /// - parameter reader: A DatabaseReader (DatabaseQueue or DatabasePool).
    /// - parameter startImmediately: When true (the default), the first
    ///   element is emitted right upon subscription.
    /// - parameter scheduler: The eventual scheduler on which elements
    ///   are emitted.
    public func fetch(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base._Reducer.Value>
    {
        var observation = base
        
        if let scheduler = scheduler {
            // Honor the scheduler parameter
            observation.scheduling = .unsafe(startImmediately: startImmediately)
            return observation.makeObservable(in: reader).observeOn(scheduler)
            
        } else if case .mainQueue = observation.scheduling , startImmediately == false {
            // Honor the startImmediately parameter
            observation.scheduling = .onQueue(DispatchQueue.main, startImmediately: false)
            return observation.makeObservable(in: reader)
            
        } else {
            // Honor observation scheduling
            return observation.makeObservable(in: reader)
        }
    }
}

extension _ValueObservationProtocol {
    fileprivate func makeObservable(in reader: DatabaseReader) -> Observable<_Reducer.Value> {
        return Observable.create { observer -> Disposable in
            do {
                let transactionObserver = try self.start(
                    in: reader,
                    onError: observer.onError,
                    onChange: observer.onNext)
                
                return Disposables.create {
                    reader.remove(transactionObserver: transactionObserver)
                }
            } catch {
                observer.onError(error)
                return Disposables.create()
            }
        }
    }
}
