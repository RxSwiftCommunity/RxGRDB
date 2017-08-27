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
        let dict = record.databaseDictionary()
        guard let rowID = dict[caseInsensitive: rowIDColumn] else {
            fatalError("Record does not encode its primary key \(rowIDColumn) in the encode(to:) method")
        }
        if let rowID = rowID {
            let rowID: Int64 = rowID.databaseValue.losslessConvert() // we need Int64
            let request = Record.filter(Column(rowIDColumn) == rowID)
            let (statement, _) = try request.prepare(db)
            self = .row(selectionInfo: statement.selectionInfo, rowIDColumn: rowIDColumn, rowID: rowID)
        } else {
            return nil // nil primary key => no observation strategy
        }
    }
    
    /// Returns nil when record has nil primary key
    init?(_ db: Database, record: Record, primaryKey: PrimaryKeyInfo) throws {
        if let rowIDColumn = primaryKey.rowIDColumn {
            try self.init(db, record: record, rowIDColumn: rowIDColumn)
            return
        }
        
        let pkColumns = primaryKey.columns
        let dict = record.databaseDictionary()
        let pkValues = pkColumns.map { column -> DatabaseValueConvertible? in
            guard let value = dict[caseInsensitive: column] else {
                fatalError("Record does not encode its primary key \(pkColumns) in the encode(to:) method")
            }
            return value
        }
        guard pkValues.contains(where: { !($0?.databaseValue ?? .null).isNull }) else {
            return nil // nil primary key => no observation strategy
        }
        let condition = pkColumns.map { "\($0.quotedDatabaseIdentifier) = ?" }.joined(separator: " AND ")
        self.init(request: Record.filter(sql: condition, arguments: StatementArguments(pkValues)))
    }
}

private extension MutablePersistable {
    func observationStrategy(_ db: Database) throws -> ObservationStrategy<Self>? {
        let primaryKey = try db.primaryKey(type(of: self).databaseTableName)
        if let primaryKey = primaryKey {
            return try ObservationStrategy(db, record: self, primaryKey: primaryKey)
        } else {
            return try ObservationStrategy(db, record: self, rowIDColumn: Column.rowID.name)
        }
    }
}

extension Observable where Element: RowConvertible & MutablePersistable {
    /// Returns an Observable that emits an optional record after each committed
    /// database transaction that has modified or deleted the row identified by
    /// the argument's primary key.
    ///
    /// For example:
    ///
    ///     let player: Player = ...
    ///     Observable.from(record: player, in: dbQueue)
    ///         .subscribe(onNext: { player in
    ///             if let player = player {
    ///                 print("player has changed")
    ///             } else {
    ///                 print("player was deleted")
    ///             }
    ///         })
    ///
    /// - parameter record: An observed record
    /// - parameter writer: A DatabaseWriter (DatabaseQueue or DatabasePool).
    /// - parameter resultQueue: A DispatchQueue (default is the main queue).
    public static func from(record: Element, in writer: DatabaseWriter, synchronizedStart: Bool = true, resultQueue: DispatchQueue = DispatchQueue.main) -> Observable {
        return Observable.create { observer in
            do {
                guard let observationStrategy = try writer.read({ try record.observationStrategy($0) }) else {
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
                    let changes: Observable<ChangeToken> = RowIDChangeTokensObserver.rx.observable(forTransactionsIn: writer) { (db, observer) in
                        if synchronizedStart {
                            observer.on(.next(ChangeToken(.initialSync(db))))
                        }
                        return RowIDChangeTokensObserver(writer: writer, selectionInfo: selectionInfo, rowID: rowID, observer: observer)
                    }
                    return changes
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
