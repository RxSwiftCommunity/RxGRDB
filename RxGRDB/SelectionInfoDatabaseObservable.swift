#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

final class SelectionInfoDatabaseObservable : ObservableType {
    typealias E = Database
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
        synchronizedStart: Bool,
        selectionInfos: @escaping (Database) throws -> [SelectStatement.SelectionInfo])
    {
        self.writer = writer
        self.synchronizedStart = synchronizedStart
        self.selectionInfos = selectionInfos
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == Database {
        do {
            let writer = self.writer
            
            let transactionObserver = try writer.unsafeReentrantWrite { db -> SelectionInfoChangeObserver in
                if synchronizedStart {
                    observer.onNext(db)
                }
                
                let transactionObserver = try SelectionInfoChangeObserver(
                    selectionInfos: selectionInfos(db),
                    onChange: { observer.onNext(db) })
                db.add(transactionObserver: transactionObserver)
                return transactionObserver
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
 