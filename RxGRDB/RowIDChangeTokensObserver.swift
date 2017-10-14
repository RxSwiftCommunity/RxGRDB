#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

final class RowIDChangeTokensObservable : ObservableType {
    typealias E = ChangeToken
    let writer: DatabaseWriter
    let synchronizedStart: Bool
    let selectionInfo: SelectStatement.SelectionInfo
    let rowID: Int64
    
    /// Creates an observable that emits `.change` tokens on the database writer
    /// queue when a transaction has modified the database in a way that impacts
    /// a specific database row.
    ///
    /// When the `synchronizedStart` argument is true, the observable also emits
    /// one `.databaseSubscription` and one `.subscription` token upon
    /// subscription, synchronously.
    ///
    /// The `.databaseSubscription` token is emitted from the database writer
    /// queue, and the `.subscription` token is emitted from the subscription
    /// dispatch queue.
    ///
    /// It is possible for concurrent threads to commit database transactions
    /// that modify the database between the `.databaseSubscription` token and
    /// the `.subscription` token. When this happens, `.change` tokens are
    /// emitted after `.databaseSubscription`, and before `.subscription`.
    init(
        writer: DatabaseWriter,
        synchronizedStart: Bool = true,
        selectionInfo: SelectStatement.SelectionInfo,
        rowID: Int64)
    {
        self.writer = writer
        self.synchronizedStart = synchronizedStart
        self.selectionInfo = selectionInfo
        self.rowID = rowID
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == ChangeToken {
        let writer = self.writer
        let transactionObserver = writer.unsafeReentrantWrite { db -> RowIDChangeObserver in
            if synchronizedStart {
                observer.onNext(ChangeToken(.databaseSubscription(db)))
            }
            
            let transactionObserver = RowIDChangeObserver(
                selectionInfo: self.selectionInfo,
                rowID: rowID,
                onChange: { observer.onNext(ChangeToken(.change(writer, db))) })
            db.add(transactionObserver: transactionObserver)
            return transactionObserver
        }
        
        if synchronizedStart {
            observer.onNext(ChangeToken(.subscription))
        }
        
        return Disposables.create {
            writer.unsafeReentrantWrite { db in
                db.remove(transactionObserver: transactionObserver)
            }
        }
    }
}

private final class RowIDChangeObserver : TransactionObserver {
    var changed: Bool = false
    let selectionInfo: SelectStatement.SelectionInfo
    let rowID: Int64
    let change: () -> Void
    
    init(selectionInfo: SelectStatement.SelectionInfo, rowID: Int64, onChange change: @escaping () -> Void) {
        self.selectionInfo = selectionInfo
        self.rowID = rowID
        self.change = change
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return eventKind.impacts(selectionInfo)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if event.rowID == rowID {
            changed = true
        }
    }
    
    func databaseWillCommit() { }
    
    func databaseDidCommit(_ db: Database) {
        // Avoid reentrancy bugs
        let changed = self.changed
        self.changed = false
        if changed {
            change()
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        changed = false
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    func databaseWillChange(with event: DatabasePreUpdateEvent) { }
    #endif
}
