#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension QueryInterfaceRequest : ReactiveCompatible { }
extension SQLRequest : ReactiveCompatible { }
extension AnyRequest : ReactiveCompatible { }
extension AnyTypedRequest : ReactiveCompatible { }

extension Reactive where Base: Request {
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first element
    /// is emitted synchronously, on subscription.
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
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    public func changes(in writer: DatabaseWriter, synchronizedStart: Bool = true) -> Observable<Database> {
        return RequestChangesObservable(writer: writer, synchronizedStart: synchronizedStart, request: base).asObservable()
    }
    
    /// Returns an Observable that emits after each committed database
    /// transaction that has modified the tables and columns fetched by
    /// the request.
    ///
    /// If you set `synchronizedStart` to true (the default), the first element
    /// is emitted synchronously, on subscription.
    ///
    ///     let dbQueue = DatabaseQueue()
    ///     let request = Person.all()
    ///     request.rx
    ///         .fetchCount(in: dbQueue)
    ///         .subscribe(onNext: { count in
    ///             print("Number of persons: \(count)")
    ///         })
    ///     // Prints "Number of persons: 0"
    ///
    ///     try dbQueue.inDatabase { db in
    ///         try Person(name: "Arthur").insert(db)
    ///         // Prints "Number of persons: 1"
    ///         try Person(name: "Barbara").insert(db)
    ///         // Prints "Number of persons: 2"
    ///     }
    ///
    ///     try dbQueue.inTransaction { db in
    ///         try Person(name: "Craig").insert(db)
    ///         try Person(name: "David").insert(db)
    ///         return .commit
    ///     }
    ///     // Prints "Number of persons: 4"
    ///
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: Whether the first element should be
    ///   emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public func fetchCount(in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable<Int> {
        return RequestFetchObservable(
            writer: writer,
            synchronizedStart: synchronizedStart,
            request: base,
            fetch: { try self.base.fetchCount($0) },
            resultQueue: resultQueue).asObservable()
    }
}

final class RequestChangesObservable<R: Request> : ObservableType {
    typealias E = Database
    
    let writer: DatabaseWriter
    let synchronizedStart: Bool
    let request: R
    
    init(writer: DatabaseWriter, synchronizedStart: Bool, request: R) {
        self.writer = writer
        self.synchronizedStart = synchronizedStart
        self.request = request
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let selectionInfo: SelectStatement.SelectionInfo
        do {
            // Use GRDB in a reentrant way in order to support retries from
            // errors that happen in a database dispatch queue.
            selectionInfo = try writer.unsafeReentrantWrite { db -> SelectStatement.SelectionInfo in
                let (statement, _) = try request.prepare(db)
                return statement.selectionInfo
            }
        } catch {
            observer.on(.error(error))
            return Disposables.create()
        }
        
        return selectionInfo.rx.changes(in: writer, synchronizedStart: synchronizedStart).subscribe(observer)
    }
}

final class RequestFetchObservable<R: Request, ResultType> : ObservableType {
    typealias E = ResultType
    
    let writer: DatabaseWriter
    let synchronizedStart: Bool
    let request: R
    let resultQueue: DispatchQueue
    let fetch: (Database) throws -> ResultType
    
    init(writer: DatabaseWriter, synchronizedStart: Bool, request: R, fetch: @escaping (Database) throws -> ResultType, resultQueue: DispatchQueue) {
        self.writer = writer
        self.synchronizedStart = synchronizedStart
        self.request = request
        self.fetch = fetch
        self.resultQueue = resultQueue
    }
    
    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, O.E == E {
        let orderingQueue = DispatchQueue(label: "RxGRDB.results")
        var synchronizedStart = self.synchronizedStart
        return AnyRequest(request).rx
            .changes(in: writer, synchronizedStart: synchronizedStart)
            .subscribe { event in
                switch event {
                case .error(let error): observer.on(.error(error))
                case .completed: observer.on(.completed)
                case .next(let db):
                    if synchronizedStart {
                        synchronizedStart = false
                        do {
                            let element = try self.fetch(db)
                            observer.on(.next(element))
                        } catch {
                            observer.on(.error(error))
                        }
                        return
                    } else {
                        // We don't want to block the writer queue longer than
                        // necessary: use writer.readFromCurrentState to perform
                        // the fetch. Since readFromCurrentState may be
                        // asynchronous, we use a semaphore to dispatch the
                        // fetched results in the correct order.
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
                                    observer.on(.next(results))
                                case .failure(let error):
                                    observer.on(.error(error))
                                }
                            }
                        }
                    }
                }
        }
    }
}
