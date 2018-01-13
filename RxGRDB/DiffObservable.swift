#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

protocol DiffStrategy {
    associatedtype Element
    associatedtype DiffType
    init(primaryKey: @escaping (Row) -> RowValue, initialElements: [Element])
    mutating func diff(from rows: [Row]) throws -> DiffType?
}

extension DiffStrategy {
    mutating func diffEvent(from rows: [Row]) -> Event<DiffType>? {
        do {
            if let diff = try self.diff(from: rows) {
                return .next(diff)
            } else {
                return nil
            }
        } catch {
            return .error(error)
        }
    }
}

extension ObservableType where E == [Row] {
    func diff<Strategy>(
        primaryKey: @escaping (Row) -> RowValue,
        initialElements: [Strategy.Element],
        synchronizedStart: Bool,
        scheduler: SerialDispatchQueueScheduler,
        stategy: Strategy.Type,
        diffQoS: DispatchQoS)
        -> Observable<Strategy.DiffType>
        where Strategy: DiffStrategy
    {
        return DiffObservable<Strategy>(
            rows: asObservable(),
            primaryKey: primaryKey,
            initialElements: initialElements,
            synchronizedStart: synchronizedStart,
            scheduler: scheduler,
            diffQoS: diffQoS)
            .asObservable()
    }
}

final class DiffObservable<Strategy: DiffStrategy> : ObservableType {
    typealias Element = Strategy.Element
    typealias E = Strategy.DiffType
    
    let rows: Observable<[Row]>
    let primaryKey: (Row) -> RowValue
    let initialElements: [Element]
    let synchronizedStart: Bool
    let scheduler: SerialDispatchQueueScheduler
    let diffQoS: DispatchQoS
    
    init(
        rows: Observable<[Row]>,
        primaryKey: @escaping (Row) -> RowValue,
        initialElements: [Element],
        synchronizedStart: Bool,
        scheduler: SerialDispatchQueueScheduler,
        diffQoS: DispatchQoS)
    {
        self.rows = rows
        self.primaryKey = primaryKey
        self.initialElements = initialElements
        self.synchronizedStart = synchronizedStart
        self.scheduler = scheduler
        self.diffQoS = diffQoS
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var strategy: Strategy! = nil
        let synchronizedStart = self.synchronizedStart
        let scheduler = self.scheduler
        let diffScheduler = SerialDispatchQueueScheduler(qos: diffQoS)

        let disposable = rows.subscribe { event in
            switch event {
            case .completed: observer.on(.completed)
            case .error(let error): observer.on(.error(error))
            case .next(let rows):
                let start: Bool
                if strategy == nil {
                    start = true
                    strategy = Strategy(primaryKey: self.primaryKey, initialElements: self.initialElements)
                } else {
                    start = false
                }
                
                if start && synchronizedStart {
                    if let event = strategy.diffEvent(from: rows) {
                        observer.on(event)
                    }
                } else {
                    _ = diffScheduler.schedule((observer, rows)) { (observer, rows) in
                        guard let event = strategy.diffEvent(from: rows) else {
                            return Disposables.create()
                        }
                        return scheduler.schedule((observer, event)) { (observer, event) in
                            observer.on(event)
                            return Disposables.create()
                        }
                    }
                }
            }
        }
        
        return Disposables.create {
            disposable.dispose()
        }
    }
}

