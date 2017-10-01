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

extension ObservableType where E == [Row] {
    func diff<Strategy>(primaryKey: @escaping (Row) -> RowValue, initialElements: [Strategy.Element], stategy: Strategy.Type) -> Observable<Strategy.DiffType>
        where Strategy: DiffStrategy
    {
        return DiffObservable<Strategy>(
            rows: asObservable(),
            primaryKey: primaryKey,
            initialElements: initialElements)
            .asObservable()
    }
}

final class DiffObservable<Strategy: DiffStrategy> : ObservableType {
    typealias Element = Strategy.Element
    typealias E = Strategy.DiffType
    
    let rows: Observable<[Row]>
    let primaryKey: (Row) -> RowValue
    let initialElements: [Element]
    
    init(rows: Observable<[Row]>, primaryKey: @escaping (Row) -> RowValue, initialElements: [Element]) {
        self.rows = rows
        self.primaryKey = primaryKey
        self.initialElements = initialElements
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var strategy: Strategy? = nil
        let disposable = rows.subscribe { event in
            switch event {
            case .completed: observer.on(.completed)
            case .error(let error): observer.on(.error(error))
            case .next(let rows):
                do {
                    if strategy == nil {
                        strategy = Strategy(primaryKey: self.primaryKey, initialElements: self.initialElements)
                    }
                    if let diff = try strategy!.diff(from: rows) {
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

