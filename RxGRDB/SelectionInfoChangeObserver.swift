#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif

extension Request {
    func selectionInfo(_ db: Database) throws -> SelectStatement.SelectionInfo {
        let (statement, _) = try prepare(db)
        return statement.selectionInfo
    }
}

final class SelectionInfoChangeObserver : TransactionObserver {
    var changed: Bool = false
    let selectionInfos: [SelectStatement.SelectionInfo]
    let change: () -> Void
    
    init(selectionInfos: [SelectStatement.SelectionInfo], onChange change: @escaping () -> Void) {
        self.selectionInfos = selectionInfos
        self.change = change
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


