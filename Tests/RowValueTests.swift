import XCTest
import GRDB
import RxSwift
@testable import RxGRDB

class RowValueTests: XCTestCase { }

extension RowValueTests {
    func testRowValueComparison() throws {
        try Test(testRowValueComparison)
            .run { try DatabaseQueue(path: $0) }
            .run { try DatabasePool(path: $0) }
    }
    
    func testRowValueComparison(writer: DatabaseWriter, disposeBag: DisposeBag) throws {
        try writer.read { db in
            let values: [DatabaseValueConvertible?] = [nil, 1, 2, 3, 1.0, 1.5, 2.0, 3.0, "1", "2", "3", "\u{00E9}", "e\u{0301}", "1".data(using: .utf8), "2".data(using: .utf8), "3".data(using: .utf8)]
            let dbValues = values.map { $0?.databaseValue ?? .null }
            let innerSQL = (["SELECT ? AS value"] + dbValues.suffix(from: 1).map { _ in "UNION ALL SELECT ?" }).joined(separator: " ")
            let sql = "SELECT value FROM (\(innerSQL)) ORDER BY value"
            do {
                let sqlSortedValues = try DatabaseValue.fetchAll(db, sql, arguments: StatementArguments(values))
                let swiftSortedValues = dbValues.sorted(by: <)
                XCTAssertEqual(sqlSortedValues.count, swiftSortedValues.count)
                for (sqlValue, swiftValue) in zip(sqlSortedValues, swiftSortedValues) {
                    XCTAssertEqual(sqlValue.storage, swiftValue.storage)
                }
            }
            do {
                let reversedValues: [DatabaseValue] = dbValues.reversed()
                let sqlSortedValues = try DatabaseValue.fetchAll(db, sql, arguments: StatementArguments(reversedValues))
                let swiftSortedValues = reversedValues.sorted(by: <)
                XCTAssertEqual(sqlSortedValues.count, swiftSortedValues.count)
                for (sqlValue, swiftValue) in zip(sqlSortedValues, swiftSortedValues) {
                    XCTAssertEqual(sqlValue.storage, swiftValue.storage)
                }
            }
        }
    }
}
