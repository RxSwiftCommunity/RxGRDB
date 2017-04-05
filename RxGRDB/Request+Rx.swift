import GRDB
import RxSwift

extension QueryInterfaceRequest : ReactiveCompatible { }
extension SQLRequest : ReactiveCompatible { }
extension AnyRequest : ReactiveCompatible { }
extension AnyTypedRequest : ReactiveCompatible { }

extension Reactive where Base: Request {
    /// Returns an Observable that emits a writer database connection
    /// immediately on subscription, and later after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     try dbQueue.inDatabase { db in
    ///         try db.create(table: "persons") { t in
    ///             t.column("id", .integer).primaryKey()
    ///             t.column("name", .text)
    ///         }
    ///     }
    ///
    ///     let request = SQLRequest("SELECT * FROM persons")
    ///     request.rx
    ///         .changes(in: dbQueue)
    ///         .subscribe(onNext: { db in
    ///             let count = try! request.fetchCount(db)
    ///             print("Number of persons: \(count)")
    ///         })
    ///     // Prints "Number of persons: 0"
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Arthur"])
    ///         // Prints "Number of persons: 1"
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Barbara"])
    ///         // Prints "Number of persons: 2"
    ///     }
    ///
    ///     try dbQueue.inTransaction { db in
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["Craig"])
    ///         try db.execute("INSERT INTO persons (name) VALUES (?)", arguments: ["David"])
    ///         return .commit
    ///     }
    ///     // Prints "Number of persons: 4"
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    public func changes(in writer: DatabaseWriter) -> Observable<Database> {
        return RequestChangesObservable(writer: writer, request: base).asObservable()
    }
}

final class RequestChangesObservable<R: Request> : ObservableType {
    typealias E = Database
    
    let writer: DatabaseWriter
    let request: R
    
    init(writer: DatabaseWriter, request: R) {
        self.writer = writer
        self.request = request
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let selectionInfo: SelectStatement.SelectionInfo
        do {
            selectionInfo = try writer.unsafeRead { db -> SelectStatement.SelectionInfo in
                let (statement, _) = try request.prepare(db)
                return statement.selectionInfo
            }
        } catch {
            observer.onError(error)
            observer.onCompleted()
            return Disposables.create()
        }
        
        return selectionInfo.rx.changes(in: writer).subscribe(observer)
    }
}
