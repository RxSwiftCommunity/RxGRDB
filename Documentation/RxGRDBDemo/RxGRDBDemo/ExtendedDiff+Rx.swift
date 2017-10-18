import RxSwift
import Differ

extension ObservableType where E: Collection {
    /// Turns a stream of collections into an observable of extended diffs,
    /// suitable for table and collection view animations.
    ///
    /// It emits pairs of (collection, diff). The diff is nil in the first pair.
    func extendedDiff(isEqual: @escaping EqualityChecker<E>) -> Observable<(E, ExtendedDiff?)> {
        return ExtendedDiffObservable(
            collection: self.asObservable(),
            isEqual: isEqual)
            .asObservable()
    }
}

extension ObservableType where E: Collection, E.Element: Equatable {
    /// Turns a stream of collections into an observable of extended diffs,
    /// suitable for table and collection view animations.
    ///
    /// It emits pairs of (collection, diff). The diff is nil in the first pair.
    ///
    /// Element comparison is based on the == operator
    func extendedDiff() -> Observable<(E, ExtendedDiff?)> {
        return extendedDiff(isEqual: ==)
    }
}

private final class ExtendedDiffObservable<C: Collection>: ObservableType {
    typealias E = (C, ExtendedDiff?)
    let collection: Observable<C>
    let isEqual: EqualityChecker<C>
    
    init(collection: Observable<C>, isEqual: @escaping EqualityChecker<C>) {
        self.collection = collection
        self.isEqual = isEqual
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, O.E == E {
        var previousCollection: C? = nil
        let isEqual = self.isEqual
        return collection.subscribe { event in
            switch event {
            case .completed:
                observer.onCompleted()
            case .error(let error):
                observer.onError(error)
            case .next(let collection):
                let diff = previousCollection?.extendedDiff(collection, isEqual: isEqual)
                previousCollection = collection
                observer.onNext((collection, diff))
            }
        }
    }
}
