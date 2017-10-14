#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

final class SelectionInfoChangeTokensObservable : ObservableType {
    typealias E = ChangeToken
    let writer: DatabaseWriter
    let synchronizedStart: Bool
    let selectionInfos: (Database) throws -> [SelectStatement.SelectionInfo]
    
    /// Creates an observable that emits `.change` tokens on the database writer
    /// queue when a transaction has modified the database in a way that impacts
    /// some requests' selections.
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
        selectionInfos: @escaping (Database) throws -> [SelectStatement.SelectionInfo])
    {
        self.writer = writer
        self.synchronizedStart = synchronizedStart
        self.selectionInfos = selectionInfos
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == ChangeToken {
        let writer = self.writer
        do {
            let transactionObserver = try writer.unsafeReentrantWrite { db -> SelectionInfoChangeObserver in
                if synchronizedStart {
                    observer.onNext(ChangeToken(.databaseSubscription(db)))
                }
                
                let selectionInfos = try self.selectionInfos(db)
                let transactionObserver = SelectionInfoChangeObserver(
                    selectionInfos: selectionInfos,
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
        } catch {
            observer.onError(error)
            return Disposables.create()
        }
    }
}

private final class SelectionInfoChangeObserver : TransactionObserver {
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
