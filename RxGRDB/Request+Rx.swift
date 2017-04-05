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
    
    /// Returns an Observable that emits an integer immediately on
    /// subscription, and later, on resultQueue, after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the Request.
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchCount(in writer: DatabaseWriter, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Int> {
        return RequestFetchObservable(
            writer: writer,
            request: base,
            fetch: { try self.base.fetchCount($0) },
            resultQueue: resultQueue).asObservable()
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

final class RequestFetchObservable<R: Request, ResultType> : ObservableType {
    typealias E = ResultType
    
    let writer: DatabaseWriter
    let request: R
    let resultQueue: DispatchQueue
    let fetch: (Database) throws -> ResultType
    
    init(writer: DatabaseWriter, request: R, fetch: @escaping (Database) throws -> ResultType, resultQueue: DispatchQueue) {
        self.writer = writer
        self.request = request
        self.fetch = fetch
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let orderingQueue = DispatchQueue(label: "RxGRDB.results")
        var initial = true
        return AnyRequest(request).rx
            .changes(in: writer)
            .subscribe { event in
                switch event {
                case .error(let error): observer.onError(error)
                case .completed: observer.onCompleted()
                case .next(let db):
                    if initial {
                        // Emit immediately on subscription
                        initial = false
                        do {
                            try observer.onNext(self.fetch(db))
                        } catch {
                            observer.onError(error)
                        }
                        return
                    }
                    
                    let semaphore = DispatchSemaphore(value: 0)
                    var result: Result<E>? = nil
                    do {
                        try self.writer.readFromCurrentState { db in
                            result = Result { try self.fetch(db) }
                            semaphore.signal()
                        }
                    } catch {
                        result = .failure(error)
                        semaphore.signal()
                    }
                    
                    orderingQueue.async {
                        _ = semaphore.wait(timeout: .distantFuture)
                        
                        // TODO: don't emit if subscription has been disposed
                        self.resultQueue.async {
                            switch result! {
                            case .success(let results):
                                observer.onNext(results)
                            case .failure(let error):
                                observer.onError(error)
                            }
                        }
                    }
                }
        }
    }
}
