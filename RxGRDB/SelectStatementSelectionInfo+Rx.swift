#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension SelectStatement.SelectionInfo : ReactiveCompatible { }

extension Reactive where Base == SelectStatement.SelectionInfo {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns described by
    /// the SelectionInfo.
    ///
    /// If you set `synchronizedStart` to true (the default), the first element
    /// is emitted synchronously, on subscription.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    public func changes(in writer: DatabaseWriter, synchronizedStart: Bool = true) -> Observable<Database> {
        return SelectionInfoChangesObservable(writer: writer, synchronizedStart: synchronizedStart, selectionInfo: base).asObservable()
    }
}

final class SelectionInfoChangesObservable : ObservableType {
    typealias E = Database
    
    let writer: DatabaseWriter
    let synchronizedStart: Bool
    let selectionInfo: SelectStatement.SelectionInfo
    
    init(writer: DatabaseWriter, synchronizedStart: Bool, selectionInfo: SelectStatement.SelectionInfo) {
        self.writer = writer
        self.synchronizedStart = synchronizedStart
        self.selectionInfo = selectionInfo
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        // A transaction observer that tracks changes in the selection
        let selectionInfoObserver = SelectionInfoObserver(selectionInfo, onChange: { db in
            observer.on(.next(db))
        })
        
        // Use GRDB in a reentrant way in order to support retries from errors
        // that happen in a database dispatch queue.
        writer.unsafeReentrantWrite { db in
            // Install transaction observer and immediately notify if requested to do so
            db.add(transactionObserver: selectionInfoObserver)
            if synchronizedStart {
                observer.on(.next(db))
            }
        }
        
        return Disposables.create {
            // Use GRDB in a reentrant way in order to support disposals that
            // happen in a database dispatch queue.
            self.writer.unsafeReentrantWrite { db in
                db.remove(transactionObserver: selectionInfoObserver)
            }
        }
    }
    
    private class SelectionInfoObserver : TransactionObserver {
        var didChange = false
        let onChange: (Database) -> ()
        let selectionInfo: SelectStatement.SelectionInfo
        
        init(_ selectionInfo: SelectStatement.SelectionInfo, onChange: @escaping (Database) -> ()) {
            self.selectionInfo = selectionInfo
            self.onChange = onChange
        }
        
        func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
            return eventKind.impacts(selectionInfo)
        }
        
        func databaseDidChange(with event: DatabaseEvent) {
            didChange = true
        }
        
        func databaseWillCommit() throws { }
        
        func databaseDidCommit(_ db: Database) {
            // Avoid reentrancy bugs...
            let needsNotify = didChange
            didChange = false
            
            // ...and notify
            if needsNotify {
                onChange(db)
            }
        }
        
        func databaseDidRollback(_ db: Database) {
            didChange = false
        }
        
        #if SQLITE_ENABLE_PREUPDATE_HOOK
        func databaseWillChange(with event: DatabasePreUpdateEvent) { }
        #endif
    }
}
