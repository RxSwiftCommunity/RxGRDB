#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// TODO
public protocol Diffable {
    func updating(with row: Row) -> Self
}

extension Diffable where Self: RowConvertible {
    public func updating(with row: Row) -> Self {
        return Self(row: row)
    }
}

extension Reactive where Base: TypedRequest, Base.RowDecoder: RowConvertible & MutablePersistable & Diffable {
    /// TODO
    public func primaryKeySortedDiff(in writer: DatabaseWriter, initialElements: [Base.RowDecoder] = []) -> Observable<PrimaryKeySortedDiff<Base.RowDecoder>> {
        return DiffObservable<Base, PrimaryKeySortedDiffStrategy<Base.RowDecoder>>(
            writer: writer,
            request: base,
            initialElements: initialElements)
            .asObservable()
    }
}

public struct PrimaryKeySortedDiff<Element> {
    public let inserted: [Element]
    public let updated: [Element]
    public let deleted: [Element]
}
