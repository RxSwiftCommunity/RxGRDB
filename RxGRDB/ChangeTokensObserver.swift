#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// TODO
class ChangeTokensObserver : TransactionObserver, ReactiveCompatible {
    var changed: Bool = false
    let writer: DatabaseWriter
    let selectionInfos: [SelectStatement.SelectionInfo]
    let observer: AnyObserver<ChangeToken>
    
    init<O>(writer: DatabaseWriter, selectionInfos: [SelectStatement.SelectionInfo], observer: O) where O: ObserverType, O.E == ChangeToken {
        self.writer = writer
        self.selectionInfos = selectionInfos
        self.observer = AnyObserver(observer)
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return selectionInfos.contains { eventKind.impacts($0) }
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        changed = true
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
