#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif

/// A "row value" https://www.sqlite.org/rowvalue.html
///
/// WARNING: the Comparable conformance does not handle database collations.
struct RowValue : Comparable {
    let dbValues: [DatabaseValue]
    
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
private func < (lhs: DatabaseValue, rhs: DatabaseValue) -> Bool {
    // sqlite> SELECT value, TYPEOF(value) FROM (
    //    ...>   SELECT NULL AS value
    //    ...>   UNION ALL SELECT 1
    //    ...>   UNION ALL SELECT 2
    //    ...>   UNION ALL SELECT 3
    //    ...>   UNION ALL SELECT 1.0
    //    ...>   UNION ALL SELECT 2.0
    //    ...>   UNION ALL SELECT 3.0
    //    ...>   UNION ALL SELECT '1'
    //    ...>   UNION ALL SELECT '2'
    //    ...>   UNION ALL SELECT '3'
    //    ...>   UNION ALL SELECT CAST('1' AS BLOB)
    //    ...>   UNION ALL SELECT CAST('2' AS BLOB)
    //    ...>   UNION ALL SELECT CAST('3' AS BLOB)
    //    ...> ) ORDER BY value;
    // |null
    // 1|integer
    // 1.0|real
    // 2|integer
    // 2.0|real
    // 3|integer
    // 3.0|real
    // 1|text
    // 2|text
    // 3|text
    // 1|blob
    // 2|blob
    // 3|blob
    // sqlite> SELECT value, TYPEOF(value) FROM (
    //    ...>   SELECT NULL AS value
    //    ...>   UNION ALL SELECT CAST('3' AS BLOB)
    //    ...>   UNION ALL SELECT CAST('2' AS BLOB)
    //    ...>   UNION ALL SELECT CAST('1' AS BLOB)
    //    ...>   UNION ALL SELECT '3'
    //    ...>   UNION ALL SELECT '2'
    //    ...>   UNION ALL SELECT '1'
    //    ...>   UNION ALL SELECT 3.0
    //    ...>   UNION ALL SELECT 2.0
    //    ...>   UNION ALL SELECT 1.0
    //    ...>   UNION ALL SELECT 3
    //    ...>   UNION ALL SELECT 2
    //    ...>   UNION ALL SELECT 1
    //    ...> ) ORDER BY value;
    // |null
    // 1.0|real
    // 1|integer
    // 2.0|real
    // 2|integer
    // 3.0|real
    // 3|integer
    // 1|text
    // 2|text
    // 3|text
    // 1|blob
    // 2|blob
    // 3|blob
    
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
        // Warning: this may not match SQLite collation
        return lhs.utf8.lexicographicallyPrecedes(rhs.utf8)
    case (.blob(let lhs), .blob(let rhs)):
        return lhs.lexicographicallyPrecedes(rhs, by: <)
    case (.blob, _): return false
    case (.string, _): return false
    case (.int64, _), (.double, _): return false
    case (.null, _): return false
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
        let columns: [String]
        if let primaryKey = try db.primaryKey(RowDecoder.databaseTableName) {
            columns = primaryKey.columns
        } else {
            columns = [Column.rowID.name]
        }
        
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

