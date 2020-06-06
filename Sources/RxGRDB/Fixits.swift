import Foundation
import GRDB
import RxSwift

extension AdaptedFetchRequest: ReactiveCompatible { }
extension AnyFetchRequest: ReactiveCompatible { }
extension QueryInterfaceRequest: ReactiveCompatible { }
extension SQLRequest: ReactiveCompatible { }

extension Reactive where Base: FetchRequest {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchCount).rx.observe(in:scheduling:) instead")
    public func observeCount(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Int>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchCount).rx.observe(in:scheduling:) instead")
    public func fetchCount(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Int>
    { preconditionFailure() }
}

extension Reactive where Base: FetchRequest, Base.RowDecoder: FetchableRecord {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func observeAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func observeFirst(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    { preconditionFailure() }
}

extension Reactive where Base: FetchRequest, Base.RowDecoder == Row {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func observeAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Row]>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Row]>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func observeFirst(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Row?>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Row?>
    { preconditionFailure() }
}

extension Reactive where Base: FetchRequest, Base.RowDecoder: DatabaseValueConvertible {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func observeAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder]>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func observeFirst(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder?>
    { preconditionFailure() }
}

extension Reactive where Base: FetchRequest, Base.RowDecoder: _OptionalProtocol, Base.RowDecoder.Wrapped: DatabaseValueConvertible {
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func observeAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder.Wrapped?]>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchAll).rx.observe(in:scheduling:) instead")
    public func fetchAll(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<[Base.RowDecoder.Wrapped?]>
    { preconditionFailure() }

    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func observeFirst(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder.Wrapped?>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use ValueObservation.tracking(request.fetchOne).rx.observe(in:scheduling:) instead")
    public func fetchOne(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.RowDecoder.Wrapped?>
    { preconditionFailure() }
}

@available(*, unavailable, message: "PrimaryKeyDiffScanner has been removed")
public struct PrimaryKeyDiffScanner<Record: FetchableRecord & MutablePersistableRecord> {
    public var diff: PrimaryKeyDiff<Record> { preconditionFailure() }
    public init<Request>(
        database: Database,
        request: Request,
        initialRecords: [Record],
        updateRecord: ((Record, Row) -> Record)? = nil)
        throws
        where Request: FetchRequest, Request.RowDecoder == Record
    { preconditionFailure() }
        
    public func diffed(from rows: [Row]) -> PrimaryKeyDiffScanner
    { preconditionFailure() }
}

@available(*, unavailable, message: "PrimaryKeyDiff has been removed")
public struct PrimaryKeyDiff<Record> {
    public var inserted: [Record]
    public var updated: [Record]
    public var deleted: [Record]
    public var isEmpty: Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
}

extension Reactive where Base: DatabaseRegionConvertible {
    @available(*, unavailable, message: "Use DatabaseRegionObservation(tracking: request).changes(in:) instead")
    public func changes(
        in writer: DatabaseWriter,
        startImmediately: Bool = true)
        -> Observable<Database>
    { preconditionFailure() }
}

extension Reactive where Base: _ValueObservationProtocol {    
    @available(*, unavailable, message: "Use observe(in:scheduling:) instead")
    public func observe(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        observeOn scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.Reducer.Value>
    { preconditionFailure() }
    
    @available(*, unavailable, message: "Use observe(in:scheduling:) instead")
    public func fetch(
        in reader: DatabaseReader,
        startImmediately: Bool = true,
        scheduler: ImmediateSchedulerType? = nil)
        -> Observable<Base.Reducer.Value>
    { preconditionFailure() }
}
