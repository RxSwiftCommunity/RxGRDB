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
    mutating func diff(_ value: Value) -> Diff?
}

public struct DiffScanner<Strategy: DiffStrategy> {
    public var strategy: Strategy
    public var diff: Strategy.Diff?
    
    init(strategy: Strategy, diff: Strategy.Diff? = nil) {
        self.strategy = strategy
        self.diff = diff
    }
    
    func scan(_ value: Strategy.Value) -> DiffScanner {
        var strategy = self.strategy
        let diff = strategy.diff(value)
        return DiffScanner(strategy: strategy, diff: diff)
    }
}

//extension ObservableType {
//    /// TODO
//    public func diff<Strategy>(
//        strategy: Strategy,
//        synchronizedStart: Bool = true,
//        scheduler: SerialDispatchQueueScheduler = MainScheduler.instance,
//        diffScheduler: SerialDispatchQueueScheduler = SerialDispatchQueueScheduler(qos: .default))
//        -> Observable<Strategy.Diff>
//        where Strategy: DiffStrategy, Strategy.Value == E
//    {
//        return DiffObservable(
//            values: asObservable(),
//            strategy: strategy,
//            synchronizedStart: synchronizedStart,
//            scheduler: scheduler,
//            diffScheduler: diffScheduler)
//            .asObservable()
//    }
//}

