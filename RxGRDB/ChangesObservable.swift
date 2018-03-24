#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

final class ChangesObservable : ObservableType {
    typealias E = Database
    let writer: DatabaseWriter
    let startImmediately: Bool
    let observedRegion: (Database) throws -> DatabaseRegion
    
    /// Creates an observable that emits writer database connections on their
    /// dedicated dispatch queue when a transaction has modified the database
    /// in a way that impacts some requests' selections.
    ///
    /// When the `startImmediately` argument is true, the observable also emits
    /// a database connection, synchronously.
    init(
        writer: DatabaseWriter,
        startImmediately: Bool,
        observedRegion: @escaping (Database) throws -> DatabaseRegion)
    {
        self.writer = writer
        self.startImmediately = startImmediately
        self.observedRegion = observedRegion
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == Database {
        do {
            let writer = self.writer
            
            let transactionObserver = try writer.unsafeReentrantWrite { db -> DatabaseRegionObserver in
                if startImmediately {
                    observer.onNext(db)
                }
                
                let transactionObserver = try DatabaseRegionObserver(
                    observedRegion: observedRegion(db),
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

