#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// The protocol for records that suit diff algorithms.
public protocol Diffable {
    /// Returns a record updated with the given row.
    func updated(with row: Row) -> Self
}

extension Diffable where Self: RowConvertible {
    public func updated(with row: Row) -> Self {
        return Self(row: row)
    }
}

extension Reactive where Base: TypedRequest, Base.RowDecoder: RowConvertible & MutablePersistable & Diffable {
    /// TODO
    public func primaryKeySortedDiff(in writer: DatabaseWriter, initialElements: [Base.RowDecoder] = []) -> Observable<PrimaryKeySortedDiff<Base.RowDecoder>> {
        let request = base
        return Observable.create { observer in
            do {
                let primaryKey = try writer.unsafeReentrantRead {
                    try request.primaryKey($0)
                }
                let diffQueue = DispatchQueue(label: "RxGRDB.diff")
                return request
                    .asRequest(of: Row.self)
                    .rx
                    .fetchAll(in: writer, resultQueue: diffQueue)
                    .diff(
                        primaryKey: primaryKey,
                        initialElements: initialElements,
                        stategy: PrimaryKeySortedDiffStrategy<Base.RowDecoder>.self)
                    .subscribe(observer)
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
