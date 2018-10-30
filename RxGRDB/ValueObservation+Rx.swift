#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

public protocol _ValueObservationProtocol: ReactiveCompatible {
    associatedtype _Reducer: ValueReducer
    var scheduling: ValueScheduling { get set }
    func start(
        in reader: DatabaseReader,
        onError: ((Error) -> Void)?,
        onChange: @escaping (_Reducer.Value) -> Void) throws -> TransactionObserver
}
extension ValueObservation: _ValueObservationProtocol where Reducer: ValueReducer {
    public typealias _Reducer = Reducer
}

extension Reactive where Base: _ValueObservationProtocol {
    /// TODO
    public func start(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base._Reducer.Value>
    {
        var observation = base
        if scheduler != nil {
            observation.scheduling = .unsafe(startImmediately: startImmediately)
        } else if startImmediately == false, case .mainQueue = observation.scheduling {
            observation.scheduling = .onQueue(DispatchQueue.main, startImmediately: false)
        }
        
        let observable: Observable<Base._Reducer.Value> = Observable.create { observer -> Disposable in
            do {
                let transactionObserver = try observation.start(
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
        
        if let scheduler = scheduler {
            return observable.observeOn(scheduler)
        } else {
            return observable
        }
    }
}
