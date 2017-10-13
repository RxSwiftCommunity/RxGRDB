#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

extension Dictionary where Key == String {
    subscript(caseInsensitive key: String) -> Value? {
        if let value = self[key] {
            return value
        }
        let lowercasedKey = key.lowercased()
        for (key, value) in self where key.lowercased() == lowercasedKey {
            return value
        }
        return nil
    }
}

private enum ObservationStrategy<Record> {
    /// A general observation strategy based on a request
    case request(QueryInterfaceRequest<Record>)
    
    /// An optimized observation strategy based on rowID
    case row(selectionInfo: SelectStatement.SelectionInfo, rowIDColumn: String, rowID: Int64)
    
    init(request: QueryInterfaceRequest<Record>) {
        self = .request(request)
    }
}

extension ObservationStrategy where Record: MutablePersistable {
    /// Returns nil when record has nil primary key
    init?(_ db: Database, record: Record, rowIDColumn: String) throws {
        let dict = record.databaseDictionary
        guard let dbValue = dict[caseInsensitive: rowIDColumn] else {
            fatalError("Record does not encode its primary key \(rowIDColumn) in the encode(to:) method")
        }
        guard let rowID = Int64.fromDatabaseValue(dbValue) else {
            return nil // nil primary key => no observation strategy
        }
        let request = Record.filter(Column(rowIDColumn) == rowID)
        let (statement, _) = try request.prepare(db)
        self = .row(selectionInfo: statement.selectionInfo, rowIDColumn: rowIDColumn, rowID: rowID)
    }
    
    /// Returns nil when record has nil primary key
    init?(_ db: Database, record: Record, primaryKey: PrimaryKeyInfo) throws {
        if let rowIDColumn = primaryKey.rowIDColumn {
            try self.init(db, record: record, rowIDColumn: rowIDColumn)
            return
        }
        
        let pkColumns = primaryKey.columns
        let dict = record.databaseDictionary
        let pkValues = pkColumns.map { column -> DatabaseValue in
            guard let value = dict[caseInsensitive: column] else {
                fatalError("Record does not encode its primary key \(pkColumns) in the encode(to:) method")
            }
            return value
        }
        guard pkValues.contains(where: { !$0.isNull }) else {
            return nil // nil primary key => no observation strategy
        }
        let condition = pkColumns.map { "\($0.quotedDatabaseIdentifier) = ?" }.joined(separator: " AND ")
        self.init(request: Record.filter(sql: condition, arguments: StatementArguments(pkValues)))
    }
}

private extension MutablePersistable {
    /// Returns nil when record has nil primary key
    func observationStrategy(_ db: Database) throws -> ObservationStrategy<Self>? {
        let primaryKey = try db.primaryKey(type(of: self).databaseTableName)
        if primaryKey.isRowID {
            return try ObservationStrategy(db, record: self, rowIDColumn: primaryKey.columns[0])
        } else {
            return try ObservationStrategy(db, record: self, primaryKey: primaryKey)
        }
    }
}

extension Observable where Element: RowConvertible & MutablePersistable {
    /// Returns an Observable that emits a record after each committed database
    /// transaction that has modified the row identified by the argument's
    /// primary key. The observable completes when the row has been deleted.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     Observable.from(record: player, in: dbQueue)
    ///         .subscribe(
    ///             onNext: { player: Player in
    ///                 print("Player has changed")
    ///             },
    ///             onCompleted: {
    ///                 print("Player was deleted")
    ///             })
    ///
    /// - parameter record: An observed record
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter synchronizedStart: When true (the default), the first
    ///   element is emitted synchronously, on subscription.
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public static func from(record: Element, in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable {
        return Observable.create { observer in
            do {
                guard let observationStrategy = try writer.unsafeReentrantRead({ try record.observationStrategy($0) }) else {
                    // No observation strategy means that record has a nil
                    // primary key and can't be tracked.
                    if synchronizedStart {
                        // Consumer expects an initial value
                        observer.on(.next(record))
                    }
                    observer.on(.completed)
                    return Disposables.create()
                }
                
                switch observationStrategy {
                // General case
                case .request(let request):
                    return request.rx
                        .fetchOne(in: writer, synchronizedStart: synchronizedStart, distinctUntilChanged: true, resultQueue: resultQueue)
                        .takeWhile { $0 != nil } // complete when record has been deleted
                        .map { $0! }
                        .subscribe(observer)
                    
                // Optimization for records whose primary key is the rowID
                case .row(let selectionInfo, let rowIDColumn, let rowID):
                    let request = Element.filter(Column(rowIDColumn) == rowID)
                    
                    return RowIDChangeTokensObservable(
                        writer: writer,
                        selectionInfo: selectionInfo,
                        rowID: rowID)
                        .mapFetch(resultQueue: resultQueue) { try Row.fetchOne($0, request) }
                        .distinctUntilChanged(==)
                        .takeWhile { $0 != nil } // complete when record has been deleted
                        .map { Element(row: $0!) }
                        .subscribe(observer)
                }
            } catch {
                observer.on(.error(error))
                return Disposables.create()
            }
        }
    }
}
