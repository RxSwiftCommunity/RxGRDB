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
    mutating func diff<RowCursor>(from rows: RowCursor) throws -> DiffType? where RowCursor: Cursor, RowCursor.Element: Row
}

extension ObservableType where E: Cursor, E.Element: Row {
    func diff<Strategy>(primaryKey: @escaping (Row) -> RowValue, initialElements: [Strategy.Element], stategy: Strategy.Type) -> Observable<Strategy.DiffType>
        where Strategy: DiffStrategy
    {
        return DiffObservable<E, Strategy>(
            rowCursors: asObservable(),
            primaryKey: primaryKey,
            initialElements: initialElements)
            .asObservable()
    }
}

final class DiffObservable<RowCursor, Strategy> : ObservableType
    where RowCursor: Cursor,
    RowCursor.Element : Row,
    Strategy: DiffStrategy
{
    typealias Element = Strategy.Element
    typealias E = Strategy.DiffType
    
    let rowCursors: Observable<RowCursor>
    let primaryKey: (Row) -> RowValue
    let initialElements: [Element]
    
    init(rowCursors: Observable<RowCursor>, primaryKey: @escaping (Row) -> RowValue, initialElements: [Element]) {
        self.rowCursors = rowCursors
        self.primaryKey = primaryKey
        self.initialElements = initialElements
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var strategy: Strategy? = nil
        let disposable = rowCursors.subscribe { event in
            switch event {
            case .completed: observer.on(.completed)
            case .error(let error): observer.on(.error(error))
            case .next(let rowCursor):
                do {
                    if strategy == nil {
                        strategy = Strategy(primaryKey: self.primaryKey, initialElements: self.initialElements)
                    }
                    if let diff = try strategy!.diff(from: rowCursor) {
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

