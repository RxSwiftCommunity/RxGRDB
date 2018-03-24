#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif

final class DatabaseRegionObserver : TransactionObserver {
    var changed: Bool = false
    let observedRegion: DatabaseRegion
    let change: () -> Void
    
    init(observedRegion: DatabaseRegion, onChange change: @escaping () -> Void) {
        self.observedRegion = observedRegion
        self.change = change
    }
    
    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        return observedRegion.isModified(byEventsOfKind:eventKind)
    }
    
    func databaseDidChange(with event: DatabaseEvent) {
        if observedRegion.isModified(by: event) {
            changed = true
            stopObservingDatabaseChangesUntilNextTransaction()
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
