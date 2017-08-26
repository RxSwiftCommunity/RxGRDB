#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// TODO
class RowIDChangeTokensObserver : TransactionObserver, ReactiveCompatible {
    var changed: Bool = false
    let writer: DatabaseWriter
    let selectionInfo: SelectStatement.SelectionInfo
    let rowID: Int64
    let observer: AnyObserver<ChangeToken>
    
    init<O>(writer: DatabaseWriter, selectionInfo: SelectStatement.SelectionInfo, rowID: Int64, observer: O) where O: ObserverType, O.E == ChangeToken {
        self.writer = writer
        self.selectionInfo = selectionInfo
        self.rowID = rowID
        self.observer = AnyObserver(observer)
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
        let didChange = changed
        changed = false
        
        if didChange {
            observer.on(.next(ChangeToken(.async(writer, db))))
        }
    }
    
    func databaseDidRollback(_ db: Database) {
        changed = false
    }
    
    #if SQLITE_ENABLE_PREUPDATE_HOOK
    func databaseWillChange(with event: DatabasePreUpdateEvent) { }
    #endif
}

