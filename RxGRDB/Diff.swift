#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// TODO
public protocol Diffable {
    func updated(with row: Row) -> Self
}

extension Diffable where Self: RowConvertible {
    public func updated(with row: Row) -> Self {
        return Self(row: row)
    }
}

extension Reactive where Base: TypedRequest, Base.RowDecoder: RowConvertible & MutablePersistable & Diffable {
    /// TODO
    public func primaryKeySortedDiff(in writer: DatabaseWriter, initialElements: [Base.RowDecoder] = [], resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<PrimaryKeySortedDiff<Base.RowDecoder>> {
        let request = base
        return Observable.create { observer in
            do {
                let primaryKey = try writer.unsafeReentrantRead {
                    try request.primaryKey($0)
                }
                let diffQueue = DispatchQueue(label: "RxGRDB.diff")
                return AnyDatabaseWriter(writer).rx
                    .changeTokens(in: [request])
                    // TODO:
                    // - When writer is DatabasePool, we want to compute the diff on the reader queue from a cursor of metal rows.
                    // - When writer is DatabaseQueue, we want to compute the diff on the distinct queue from a cursor of copied rows.
                    // Below we are processing a cursor of row copies on a distinct queue:
                    .mapFetch(resultQueue: diffQueue) {
                        try IteratorCursor(Row.fetchAll($0, request).makeIterator())
                    }
                    .diff(
                        primaryKey: primaryKey,
                        initialElements: initialElements,
                        stategy: PrimaryKeySortedDiffStrategy<Base.RowDecoder>.self)
                    .subscribe { event in
                        resultQueue.async {
                            observer.on(event)
                        }
                }
            } catch {
                observer.on(.error(error))
                return Disposables.create()
            }
        }
    }
}

public struct PrimaryKeySortedDiff<Element> {
    public let inserted: [Element]
    public let updated: [Element]
    public let deleted: [Element]
}
