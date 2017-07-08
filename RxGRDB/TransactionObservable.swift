#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// An observable that wraps a GRDB's TransactionObserver.
final class TransactionObservable<TransactionO, Element> : ObservableType where TransactionO: TransactionObserver {
    typealias E = Element
    
    let writer: DatabaseWriter
    private let transactionObserver: (Database, PublishSubject<Element>) throws -> TransactionO
    
    init(writer: DatabaseWriter, subscribeWith transactionObserver: @escaping (Database, PublishSubject<Element>) throws -> TransactionO) {
        self.writer = writer
        self.transactionObserver = transactionObserver
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        // Talk to observer through a subject
        let subject = PublishSubject<E>()
        let subjectSubscription = subject.subscribe(observer)
        
        do {
            var transactionObserver: TransactionO! = nil
            
            try writer.unsafeReentrantWrite { db in
                transactionObserver = try self.transactionObserver(db, subject)
                db.add(transactionObserver: transactionObserver)
            }
            
            return Disposables.create {
                subjectSubscription.dispose()
                self.writer.unsafeReentrantWrite { db in
                    db.remove(transactionObserver: transactionObserver)
                }
            }
        } catch {
            subject.on(.error(error))
            return subjectSubscription
        }
    }
}

extension Reactive where Base: TransactionObserver {
    
    /// Not public yet
    static func observable<Element>(forTransactionsIn writer: DatabaseWriter, subscribeWith transactionObserver: @escaping (Database, PublishSubject<Element>) throws -> Base) -> Observable<Element> {
        return TransactionObservable(
            writer: writer,
            subscribeWith: transactionObserver)
            .asObservable()
    }
}
