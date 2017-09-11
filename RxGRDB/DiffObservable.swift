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

final class DiffObservable<Request: TypedRequest, Strategy: DiffStrategy> : ObservableType where Strategy.Element == Request.RowDecoder {
    typealias Element = Strategy.Element
    typealias E = Strategy.DiffType
    
    let writer: DatabaseWriter
    let request: Request
    let initialElements: [Element]
    
    init(writer: DatabaseWriter, request: Request, initialElements: [Element]) {
        self.writer = writer
        self.request = request
        self.initialElements = initialElements
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        do {
            let request = self.request
            var strategy = try writer.unsafeReentrantRead { db in
                try Strategy(db, request: request, initialElements: initialElements)
            }
            
            return AnyDatabaseWriter(writer).rx
                .changeTokens(in: [request])
                .mapFetch { db in try strategy.diff(from: Row.fetchCursor(db, request)) }
                .flatMap { diff -> Observable<E> in diff.map { .just($0) } ?? .empty() }
                .subscribe(observer)
        } catch {
            observer.onError(error)
            return Disposables.create()
        }
    }
}

