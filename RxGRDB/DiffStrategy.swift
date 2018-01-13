import RxSwift

/// The DiffStrategy helps building observables that emit diffs out of a
/// sequence of values.
///
/// For example,
public protocol DiffStrategy {
    /// The type of input values
    associatedtype Value
    
    /// The type of diffs between two values
    associatedtype Diff
    
    /// Returns the diff from the previous value.
    ///
    /// The result is nil if and only if the new value is identical to the
    /// previous value.
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
