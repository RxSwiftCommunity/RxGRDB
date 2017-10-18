#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif

/// A "row value" https://www.sqlite.org/rowvalue.html
///
/// WARNING: the Comparable conformance does not handle database collations.
struct RowValue {
    let dbValues: [DatabaseValue]
}

extension RowValue : Comparable {
    static func < (lhs: RowValue, rhs: RowValue) -> Bool {
        return lhs.dbValues.lexicographicallyPrecedes(rhs.dbValues, by: <)
    }
    
    static func == (lhs: RowValue, rhs: RowValue) -> Bool {
        return lhs.dbValues == rhs.dbValues
    }
}

/// Compares DatabaseValue like SQLite
///
/// WARNING: this comparison does not handle database collations.
func < (lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.int64(let lhs), .int64(let rhs)):
        return lhs < rhs
    case (.double(let lhs), .double(let rhs)):
        return lhs < rhs
    case (.int64(let lhs), .double(let rhs)):
        return Double(lhs) < rhs
    case (.double(let lhs), .int64(let rhs)):
        return lhs < Double(rhs)
    case (.string(let lhs), .string(let rhs)):
        return lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    case (.blob(let lhs), .blob(let rhs)):
        return lhs.lexicographicallyPrecedes(rhs, by: <)
    case (.blob, _):
        return false
    case (_, .blob):
        return true
    case (.string, _):
        return false
    case (_, .string):
        return true
    case (.int64, _), (.double, _):
        return false
    case (_, .int64), (_, .double):
        return true
    case (.null, _):
        return false
    case (_, .null):
        return true
    }
}

extension TypedRequest where RowDecoder: TableMapping {
    /// Creates a function that extracts the primary key from a row
    ///
    ///     let request = Player.all()
    ///     let primaryKey = try request.primaryKey(db)
    ///     if let row = try Row.fetchOne(db, request) {
    ///         print(row) // <Row id:1, name:"arthur", score:1000>
    ///         primaryKey(row) // [1]
    ///     }
    func primaryKey(_ db: Database) throws -> (Row) -> RowValue {
        // Extract primary key columns
        let columns = try db.primaryKey(RowDecoder.databaseTableName).columns
        
        // Turn column names into statement indexes
        let (statement, rowAdapter) = try prepare(db)
        let rowLayout: RowLayout = try rowAdapter?.layoutedAdapter(from: statement).mapping ?? statement
        let indexes = columns.map { column -> Int in
            guard let index = rowLayout.layoutIndex(ofColumn: column) else {
                fatalError("Primary key column \(String(reflecting: column)) is not selected")
            }
            return index
        }
        
        // Turn statement indexes into values
        return { (row: Row) in
            RowValue(dbValues: indexes.map { row[$0] })
        }
    }
}

