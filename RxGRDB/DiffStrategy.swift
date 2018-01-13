import RxSwift

/// TODO
public protocol DiffStrategy {
    /// TODO
    associatedtype Value
    /// TODO
    associatedtype Diff
    /// TODO
    mutating func diff(_ value: Value) throws -> Diff?
}

extension ObservableType {
    /// TODO
    public func diff<Strategy>(
        strategy: Strategy,
        synchronizedStart: Bool = true,
        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance,
        diffQoS: DispatchQoS = .default)
        -> Observable<Strategy.Diff>
        where Strategy: DiffStrategy, Strategy.Value == E
    {
        return DiffObservable(
            values: asObservable(),
            strategy: strategy,
            synchronizedStart: synchronizedStart,
            scheduler: scheduler,
            diffQoS: diffQoS)
            .asObservable()
    }
}
