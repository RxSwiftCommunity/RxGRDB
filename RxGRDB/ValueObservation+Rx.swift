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
    /// TODO
    public func start(
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
