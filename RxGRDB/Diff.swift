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

extension ObservableType where E == ChangeToken {
    /// TODO
    public func primaryKeySortedDiff<Request>(request: Request, initialElements: [Request.RowDecoder]) -> Observable<PrimaryKeySortedDiff<Request.RowDecoder>>
    where Request: TypedRequest, Request.RowDecoder: RowConvertible & MutablePersistable & Diffable
    {
        return diff(
            request: request,
            initialElements: initialElements,
            stategy: PrimaryKeySortedDiffStrategy<Request.RowDecoder>.self)
    }
}

extension Reactive where Base: TypedRequest, Base.RowDecoder: RowConvertible & MutablePersistable & Diffable {
    /// TODO
    public func primaryKeySortedDiff(in writer: DatabaseWriter, initialElements: [Base.RowDecoder] = []) -> Observable<PrimaryKeySortedDiff<Base.RowDecoder>> {
        return AnyDatabaseWriter(writer).rx
            .changeTokens(in: [base])
            .primaryKeySortedDiff(
                request: base,
                initialElements: initialElements)
    }
}

public struct PrimaryKeySortedDiff<Element> {
    public let inserted: [Element]
    public let updated: [Element]
    public let deleted: [Element]
}
