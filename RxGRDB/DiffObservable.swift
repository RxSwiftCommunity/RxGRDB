#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

protocol DiffStrategy {
    associatedtype Element
    associatedtype DiffType
    init<R>(_ db: Database, request: R, initialElements: [Element]) throws where R: TypedRequest, R.RowDecoder == Element
    mutating func diff(from rows: RowCursor) throws -> DiffType?
}

extension ObservableType where E == ChangeToken {
    func diff<Request, Strategy>(request: Request, initialElements: [Request.RowDecoder], stategy: Strategy.Type) -> Observable<Strategy.DiffType>
        where Request: TypedRequest,
        Strategy: DiffStrategy,
        Request.RowDecoder == Strategy.Element
    {
        return DiffObservable<Request, Strategy>(
            changeTokens: asObservable(),
            request: request,
            initialElements: initialElements).asObservable()
    }
}

final class DiffObservable<Request: TypedRequest, Strategy: DiffStrategy> : ObservableType where Strategy.Element == Request.RowDecoder {
    typealias Element = Strategy.Element
    typealias E = Strategy.DiffType
    
    let changeTokens: Observable<ChangeToken>
    let request: Request
    let initialElements: [Element]
    
    init(changeTokens: Observable<ChangeToken>, request: Request, initialElements: [Element]) {
        self.changeTokens = changeTokens
        self.request = request
        self.initialElements = initialElements
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var strategy: Strategy? = nil
        let disposable = changeTokens.subscribe { event in
            switch event {
            case .completed: observer.on(.completed)
            case .error(let error): observer.on(.error(error))
            case .next(let changeToken):
                do {
                    let db = changeToken.database
                    if strategy == nil {
                        strategy = try Strategy(db, request: self.request, initialElements: self.initialElements)
                    }
                    if let diff = try strategy!.diff(from: Row.fetchCursor(db, self.request)) {
                        observer.on(.next(diff))
                    }
                } catch {
                    observer.on(.error(error))
                }
            }
        }
        return Disposables.create {
            disposable.dispose()
        }
    }

}

