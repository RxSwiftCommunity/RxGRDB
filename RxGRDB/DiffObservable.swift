//#if USING_SQLCIPHER
//    import GRDBCipher
//#else
//    import GRDB
//#endif
//import RxSwift
//
//extension DiffStrategy {
//    mutating func diffEvent(_ value: Value) -> Event<Diff>? {
//        do {
//            if let diff = try self.diff(value) {
//                return .next(diff)
//            } else {
//                return nil
//            }
//        } catch {
//            return .error(error)
//        }
//    }
//}
//
//final class DiffObservable<Strategy: DiffStrategy> : ObservableType {
//    typealias E = Strategy.Diff
//
//    let values: Observable<Strategy.Value>
//    let strategy: Strategy
//    let synchronizedStart: Bool
//    let scheduler: SerialDispatchQueueScheduler
//    let diffScheduler: SerialDispatchQueueScheduler
//
//    init(
//        values: Observable<Strategy.Value>,
//        strategy: Strategy,
//        synchronizedStart: Bool,
//        scheduler: SerialDispatchQueueScheduler,
//        diffScheduler: SerialDispatchQueueScheduler)
//    {
//        self.values = values
//        self.strategy = strategy
//        self.synchronizedStart = synchronizedStart
//        self.scheduler = scheduler
//        self.diffScheduler = diffScheduler
//    }
//
//    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
//        var strategy: Strategy = self.strategy
//        var synchronizedStart = self.synchronizedStart
//        let scheduler = self.scheduler
//        let diffScheduler = self.diffScheduler
//
//        let disposable = values.subscribe { event in
//            switch event {
//            case .completed: observer.on(.completed)
//            case .error(let error): observer.on(.error(error))
//            case .next(let value):
//                if synchronizedStart {
//                    synchronizedStart = false
//                    if let event = strategy.diffEvent(value) {
//                        observer.on(event)
//                    }
//                } else {
//                    _ = diffScheduler.schedule((observer, value)) { (observer, value) in
//                        guard let event = strategy.diffEvent(value) else {
//                            return Disposables.create()
//                        }
//                        return scheduler.schedule((observer, event)) { (observer, event) in
//                            observer.on(event)
//                            return Disposables.create()
//                        }
//                    }
//                }
//            }
//        }
//
//        return Disposables.create {
//            disposable.dispose()
//        }
//    }
//}
//
