import Foundation
import GRDB
import RxSwift

extension Reactive where Base: TypedRequest, Base.Fetched: RowConvertible {
    /// Returns an Observable that emits a array of records immediately on
    /// subscription, and later, on resultQueue, after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchAll(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<[Base.Fetched]> {
        return RequestFetchObservable(
            writer: writer,
            request: base,
            fetch: { try self.base.fetchAll($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    /// Returns an Observable that emits a single option record immediately on
    /// subscription, and later, on resultQueue, after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchOne(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Base.Fetched?> {
        return RequestFetchObservable(
            writer: writer,
            request: base,
            fetch: { try self.base.fetchOne($0) },
            resultQueue: resultQueue).asObservable()
    }
    
    public func diff(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<(RequestResults<Base.Fetched>, RequestDiff)> {
        let diffQueue = DispatchQueue(label: "ReactiveGRDB.diff")
        let items = base.bound(to: Item<Base.Fetched>.self).rx.fetchAll(in: writer, resultQueue: diffQueue)
        return Diff(items: items.asObservable(), resultQueue: resultQueue).asObservable()
    }
}

public struct RequestResults<Fetched: RowConvertible> {
    fileprivate let items: [Item<Fetched>]
    
    fileprivate init(items: [Item<Fetched>]) {
        self.items = items
    }
    
    public subscript(_ indexPath: IndexPath) -> Fetched {
        return items[indexPath[1]].record
    }
}

public enum RequestDiff {
    case snapshot
    case changes([Change])
    
    public enum Change {
        /// An insertion event, at given indexPath.
        case insertion(indexPath: IndexPath)
        
        /// A deletion event, at given indexPath.
        case deletion(indexPath: IndexPath)
        
        /// A move event, from indexPath to newIndexPath. The *changes* are a
        /// dictionary whose keys are column names, and values the old values that
        /// have been changed.
        case move(indexPath: IndexPath, newIndexPath: IndexPath, changes: [String: DatabaseValue])
        
        /// An update event, at given indexPath. The *changes* are a dictionary
        /// whose keys are column names, and values the old values that have
        /// been changed.
        case update(indexPath: IndexPath, changes: [String: DatabaseValue])
    }
}

final class Item<Fetched: RowConvertible> : RowConvertible, Equatable {
    let row: Row
    
    // Records are lazily loaded
    lazy var record: Fetched = {
        var record = Fetched(row: self.row)
        record.awakeFromFetch(row: self.row)
        return record
    }()
    
    public init(row: Row) {
        self.row = row.copy()
    }
    
    public static func ==(lhs: Item, rhs: Item) -> Bool {
        return lhs.row == rhs.row
    }
}

final class Diff<Fetched> : ObservableType where Fetched: RowConvertible {
    typealias E = (RequestResults<Fetched>, RequestDiff)
    
    let items: Observable<[Item<Fetched>]>
    let resultQueue: DispatchQueue
    
    init(items: Observable<[Item<Fetched>]>, resultQueue: DispatchQueue) {
        self.items = items
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        var lastItems: [Item<Fetched>]? = nil
        
        return items.subscribe { event in
            switch event {
            case .next(let new):
                if let last = lastItems {
                    // TODO: compute changes from last to items
                    let pair: E = (RequestResults(items: new), .changes([]))
                    lastItems = new
                    self.resultQueue.async {
                        observer.onNext(pair)
                    }
                } else {
                    // Emit immediately on subscription
                    lastItems = new
                    observer.onNext((RequestResults(items: new), .snapshot))
                }
            case .error(let error):
                self.resultQueue.async {
                    observer.onError(error)
                }
            case .completed:
                self.resultQueue.async {
                    observer.onCompleted()
                }
            }
        }
    }
}
