import Foundation
#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension Reactive where Base: TypedRequest, Base.RowDecoder: RowConvertible & TableMapping {
    public func diff(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<(RequestResults<Base.RowDecoder>, RequestEvent<Base.RowDecoder>)> {
        let diffQueue = DispatchQueue(label: "RxGRDB.diff")
        let items = base.asRequest(of: Item<Base.RowDecoder>.self).rx.fetchAll(in: writer, resultQueue: diffQueue)
        return Diff(reader: writer, items: items.asObservable(), resultQueue: resultQueue).asObservable()
    }
}

public struct RequestResults<Record: RowConvertible> {
    fileprivate let items: [Item<Record>]
    
    fileprivate init(items: [Item<Record>]) {
        self.items = items
    }
    
    var count: Int {
        return items.count
    }
    
    public subscript(_ index: Int) -> Record {
        return items[index].record
    }
    
    public subscript(_ indexPath: IndexPath) -> Record {
        return items[indexPath[1]].record
    }
}

public enum RequestEvent<Record: RowConvertible> {
    case snapshot
    case changes([Change])
    
    public struct Change {
        let item: Item<Record>
        let kind: Kind
        
        public var record: Record { return item.record }
        
        public enum Kind {
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
    
    
}

final class Item<Record: RowConvertible> : RowConvertible, Equatable {
    let row: Row
    
    // Records are lazily loaded
    lazy var record: Record = Record(row: self.row)
    
    public init(row: Row) {
        self.row = row.copy()
    }
    
    public static func ==(lhs: Item, rhs: Item) -> Bool {
        return lhs.row == rhs.row
    }
}

final class Diff<Record> : ObservableType where Record: RowConvertible & TableMapping {
    typealias E = (RequestResults<Record>, RequestEvent<Record>)
    
    let reader: DatabaseReader
    let items: Observable<[Item<Record>]>
    let resultQueue: DispatchQueue
    
    init(reader: DatabaseReader, items: Observable<[Item<Record>]>, resultQueue: DispatchQueue) {
        self.reader = reader
        self.items = items
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        do {
            let rowComparator = try reader.unsafeRead { try Record.primaryKeyRowComparator($0) }
            let itemsAreIdentical: ItemComparator<Record> = { rowComparator($0.row, $1.row) }
            
            var lastItems: [Item<Record>]? = nil
            return items.subscribe { event in
                switch event {
                case .next(let new):
                    if let last = lastItems {
                        let changes = computeChanges(from: last, to: new, itemsAreIdentical: itemsAreIdentical)
                        if changes.isEmpty { return }
                        let result: E = (RequestResults(items: new), .changes(changes))
                        lastItems = new
                        self.resultQueue.async {
                            observer.on(.next(result))
                        }
                    } else {
                        // Emit immediately on subscription
                        lastItems = new
                        observer.on(.next((RequestResults(items: new), .snapshot)))
                    }
                case .error(let error):
                    self.resultQueue.async {
                        observer.on(.error(error))
                    }
                case .completed:
                    self.resultQueue.async {
                        observer.on(.completed)
                    }
                }
            }
        } catch {
            observer.on(.error(error))
            return Disposables.create()
        }
    }
}

fileprivate typealias ItemComparator<Record: RowConvertible> = (Item<Record>, Item<Record>) -> Bool

fileprivate func computeChanges<Record>(from s: [Item<Record>], to t: [Item<Record>], itemsAreIdentical: ItemComparator<Record>) -> [RequestEvent<Record>.Change] {
    typealias Change = RequestEvent<Record>.Change
    
    let m = s.count
    let n = t.count
    
    // Fill first row and column of insertions and deletions.
    
    var d: [[[RequestEvent<Record>.Change]]] = Array(repeating: Array(repeating: [], count: n + 1), count: m + 1)
    
    var changes = [Change]()
    for (row, item) in s.enumerated() {
        let deletion = Change(item: item, kind: .deletion(indexPath: IndexPath(indexes: [0, row])))
        changes.append(deletion)
        d[row + 1][0] = changes
    }
    
    changes.removeAll()
    for (col, item) in t.enumerated() {
        let insertion = Change(item: item, kind: .insertion(indexPath: IndexPath(indexes: [0, col])))
        changes.append(insertion)
        d[0][col + 1] = changes
    }
    
    if m == 0 || n == 0 {
        // Pure deletions or insertions
        return d[m][n]
    }
    
    // Fill body of matrix.
    for tx in 0..<n {
        for sx in 0..<m {
            if s[sx] == t[tx] {
                d[sx+1][tx+1] = d[sx][tx] // no operation
            } else {
                var del = d[sx][tx+1]     // a deletion
                var ins = d[sx+1][tx]     // an insertion
                var sub = d[sx][tx]       // a substitution
                
                // Record operation.
                let minimumCount = min(del.count, ins.count, sub.count)
                if del.count == minimumCount {
                    let deletion = Change(item: s[sx], kind: .deletion(indexPath: IndexPath(indexes: [0, sx])))
                    del.append(deletion)
                    d[sx+1][tx+1] = del
                } else if ins.count == minimumCount {
                    let insertion = Change(item: t[tx], kind: .insertion(indexPath: IndexPath(indexes: [0, tx])))
                    ins.append(insertion)
                    d[sx+1][tx+1] = ins
                } else {
                    let deletion = Change(item: s[sx], kind: .deletion(indexPath: IndexPath(indexes: [0, sx])))
                    let insertion = Change(item: t[tx], kind: .insertion(indexPath: IndexPath(indexes: [0, tx])))
                    sub.append(deletion)
                    sub.append(insertion)
                    d[sx+1][tx+1] = sub
                }
            }
        }
    }
    
    /// Returns an array where deletion/insertion pairs of the same element are replaced by `.move` change.
    func standardize(changes: [RequestEvent<Record>.Change], itemsAreIdentical: ItemComparator<Record>) -> [RequestEvent<Record>.Change] {
        
        /// Returns a potential .move or .update if *change* has a matching change in *changes*:
        /// If *change* is a deletion or an insertion, and there is a matching inverse
        /// insertion/deletion with the same value in *changes*, a corresponding .move or .update is returned.
        /// As a convenience, the index of the matched change is returned as well.
        func merge(change: RequestEvent<Record>.Change, in changes: [RequestEvent<Record>.Change], itemsAreIdentical: ItemComparator<Record>) -> (mergedChange: RequestEvent<Record>.Change, mergedIndex: Int)? {
            
            /// Returns the changes between two rows: a dictionary [key: oldValue]
            /// Precondition: both rows have the same columns
            func changedValues(from oldRow: Row, to newRow: Row) -> [String: DatabaseValue] {
                var changedValues: [String: DatabaseValue] = [:]
                for (column, newValue) in newRow {
                    let oldValue: DatabaseValue? = oldRow.value(named: column)
                    if newValue != oldValue {
                        changedValues[column] = oldValue
                    }
                }
                return changedValues
            }
            
            switch change.kind {
            case .insertion(let newIndexPath):
                // Look for a matching deletion
                for (index, otherChange) in changes.enumerated() {
                    guard case .deletion(let oldIndexPath) = otherChange.kind else { continue }
                    let oldItem = otherChange.item
                    let newItem = change.item
                    guard itemsAreIdentical(oldItem, newItem) else { continue }
                    let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                    if oldIndexPath == newIndexPath {
                        return (Change(item: newItem, kind: .update(indexPath: oldIndexPath, changes: rowChanges)), index)
                    } else {
                        return (Change(item: newItem, kind: .move(indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges)), index)
                    }
                }
                return nil
                
            case .deletion(let oldIndexPath):
                // Look for a matching insertion
                for (index, otherChange) in changes.enumerated() {
                    guard case .insertion(let newIndexPath) = otherChange.kind else { continue }
                    let oldItem = change.item
                    let newItem = otherChange.item
                    guard itemsAreIdentical(change.item, newItem) else { continue }
                    let rowChanges = changedValues(from: oldItem.row, to: newItem.row)
                    if oldIndexPath == newIndexPath {
                        return (Change(item: newItem, kind: .update(indexPath: oldIndexPath, changes: rowChanges)), index)
                    } else {
                        return (Change(item: newItem, kind: .move(indexPath: oldIndexPath, newIndexPath: newIndexPath, changes: rowChanges)), index)
                    }
                }
                return nil
                
            default:
                return nil
            }
        }
        
        // Updates must be pushed at the end
        var mergedChanges: [RequestEvent<Record>.Change] = []
        var updateChanges: [RequestEvent<Record>.Change] = []
        for change in changes {
            if let (mergedChange, mergedIndex) = merge(change: change, in: mergedChanges, itemsAreIdentical: itemsAreIdentical) {
                mergedChanges.remove(at: mergedIndex)
                switch mergedChange.kind {
                case .update:
                    updateChanges.append(mergedChange)
                default:
                    mergedChanges.append(mergedChange)
                }
            } else {
                mergedChanges.append(change)
            }
        }
        return mergedChanges + updateChanges
    }
    
    return standardize(changes: d[m][n], itemsAreIdentical: itemsAreIdentical)
}
