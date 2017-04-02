import RxSwift

extension ObservableType {
    /// Returns an observable that combines elements by pair
    func pairs() -> Observable<(E, E)> {
        return Pairs(source: self.asObservable()).asObservable()
    }
}

final class Pairs<SourceType> : ObservableType {
    typealias E = (SourceType, SourceType)
    
    let source: Observable<SourceType>
    
    init(source: Observable<SourceType>) {
        self.source = source
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var lastElement: SourceType? = nil
        
        return source.subscribe { event in
            switch event {
            case .next(let element):
                if let last = lastElement {
                    let pair = (last, element)
                    lastElement = element
                    observer.onNext(pair)
                } else {
                    lastElement = element
                }
            case .error(let error):
                observer.onError(error)
            case .completed:
                observer.onCompleted()
            }
        }
    }
}

