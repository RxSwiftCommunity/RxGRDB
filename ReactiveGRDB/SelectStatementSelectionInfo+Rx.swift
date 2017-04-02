import GRDB
import RxSwift

extension SelectStatement.SelectionInfo : ReactiveCompatible { }

extension Reactive where Base == SelectStatement.SelectionInfo {
    /// Returns an Observable that emits a writer database connection
    /// immediately on subscription, and later after each committed database
    /// transaction that has modified the tables and columns described by
    /// the SelectionInfo.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    public func changes(in writer: DatabaseWriter) -> Observable<Database> {
        return SelectionInfoChangesObservable(writer: writer, selectionInfo: base).asObservable()
    }
}

final class SelectionInfoChangesObservable: ObservableType {
    typealias E = Database
    
    let writer: DatabaseWriter
    let selectionInfo: SelectStatement.SelectionInfo
    
    init(writer: DatabaseWriter, selectionInfo: SelectStatement.SelectionInfo) {
        self.writer = writer
        self.selectionInfo = selectionInfo
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        // Observes transactions that change tracked selection
        let selectionInfoObserver = SelectionInfoObserver(selectionInfo, onChange: { db in
            observer.onNext(db)
        })
        
        // Install transction observer and immediately notify from the writer queue
        writer.write { db in
            db.add(transactionObserver: selectionInfoObserver)
            observer.onNext(db)
        }
        
        return Disposables.create {
            self.writer.remove(transactionObserver: selectionInfoObserver)
        }
    }
    
    private final class SelectionInfoObserver : GRDB.TransactionObserver {
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
