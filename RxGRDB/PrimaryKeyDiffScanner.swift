#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif

/// TODO
public struct PrimaryKeyDiffScanner<Record: FetchableRecord & MutablePersistableRecord> {
    private let primaryKey: (Row) -> RowValue
    private let updateRecord: (Record, Row) -> Record
    private let references: [Reference]
    
    /// TODO
    public let diff: PrimaryKeyDiff<Record>
    
    private struct Reference {
        let primaryKey: RowValue // Allows to sort records by primary key
        let row: Row             // Allows to identify identical records
        let record: Record       // A record
    }
    
    /// TODO
    public init<Request>(
        database: Database,
        request: Request,
        initialRecords: [Record],
        updateRecord: ((Record, Row) -> Record)? = nil)
        throws
        where Request: FetchRequest, Request.RowDecoder == Record
    {
        let primaryKey = try request.primaryKey(database)
        let references = initialRecords.map { record -> Reference in
            let row = Row(record.databaseDictionary)
            return Reference(
                primaryKey: primaryKey(row),
                row: row,
                record: record)
        }
        self.init(
            primaryKey: primaryKey,
            updateRecord: updateRecord ?? { (_, row) in Record(row: row) },
            references: references,
            diff: PrimaryKeyDiff(inserted: [], updated: [], deleted: []))
    }
        
    private init(
        primaryKey: @escaping (Row) -> RowValue,
        updateRecord: @escaping (Record, Row) -> Record,
        references: [Reference],
        diff: PrimaryKeyDiff<Record>)
    {
        self.primaryKey = primaryKey
        self.updateRecord = updateRecord
        self.references = references
        self.diff = diff
    }

    public func diffed(from rows: [Row]) -> PrimaryKeyDiffScanner {
        let primaryKey = self.primaryKey
        let newRecords = rows.map { (primaryKey: primaryKey($0), row: $0) }

        var inserted: [Record] = []
        var updated: [Record] = []
        var deleted: [Record] = []
        var nextReferences: [Reference] = []

        let mergeSteps = sortedMerge(
            left: references,
            right: newRecords,
            leftKey: { $0.primaryKey },
            rightKey: { $0.primaryKey })
        for step in mergeSteps {
            switch step {
            case .left(let previous):
                // Deletion
                deleted.append(previous.record)
            case .common(let previous, let new):
                // Update
                if new.row == previous.row {
                    nextReferences.append(previous)
                } else {
                    let newRecord = updateRecord(previous.record, new.row)
                    updated.append(newRecord)
                    nextReferences.append(Reference(primaryKey: previous.primaryKey, row: new.row, record: newRecord))
                }
            case .right(let new):
                // Insertion
                let record = Record(row: new.row)
                inserted.append(record)
                nextReferences.append(Reference(primaryKey: new.primaryKey, row: new.row, record: record))
            }
        }
        
        let diff = PrimaryKeyDiff(
            inserted: inserted,
            updated: updated,
            deleted: deleted)
        
        return PrimaryKeyDiffScanner(
            primaryKey: primaryKey,
            updateRecord: updateRecord,
            references: nextReferences,
            diff: diff)
    }
}

public struct PrimaryKeyDiff<Record> {
    public var inserted: [Record]
    public var updated: [Record]
    public var deleted: [Record]
    public var isEmpty: Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
}

/// Given two sorted sequences (left and right), this function emits "merge steps"
/// which tell whether elements are only found on the left, on the right, or on
/// both sides.
///
/// Both sequences do not have to share the same element type. Yet elements must
/// share a common comparable *key*.
///
/// Both sequences must be sorted by this key.
///
/// Keys must be unique in both sequences.
///
/// The example below compare two sequences sorted by integer representation,
/// and prints:
///
/// - Left: 1
/// - Common: 2, 2
/// - Common: 3, 3
/// - Right: 4
///
///     for mergeStep in sortedMerge(
///         left: [1,2,3],
///         right: ["2", "3", "4"],
///         leftKey: { $0 },
///         rightKey: { Int($0)! })
///     {
///         switch mergeStep {
///         case .left(let left):
///             print("- Left: \(left)")
///         case .right(let right):
///             print("- Right: \(right)")
///         case .common(let left, let right):
///             print("- Common: \(left), \(right)")
///         }
///     }
///
/// - parameters:
///     - left: The left sequence.
///     - right: The right sequence.
///     - leftKey: A function that returns the key of a left element.
///     - rightKey: A function that returns the key of a right element.
/// - returns: A sequence of MergeStep
func sortedMerge<LeftSequence: Sequence, RightSequence: Sequence, Key: Comparable>(
    left lSeq: LeftSequence,
    right rSeq: RightSequence,
    leftKey: @escaping (LeftSequence.Element) -> Key,
    rightKey: @escaping (RightSequence.Element) -> Key) -> AnySequence<MergeStep<LeftSequence.Element, RightSequence.Element>>
{
    return AnySequence { () -> AnyIterator<MergeStep<LeftSequence.Element, RightSequence.Element>> in
        var (lGen, rGen) = (lSeq.makeIterator(), rSeq.makeIterator())
        var (lOpt, rOpt) = (lGen.next(), rGen.next())
        return AnyIterator {
            switch (lOpt, rOpt) {
            case (let lElem?, let rElem?):
                let (lKey, rKey) = (leftKey(lElem), rightKey(rElem))
                if lKey > rKey {
                    rOpt = rGen.next()
                    return .right(rElem)
                } else if lKey == rKey {
                    (lOpt, rOpt) = (lGen.next(), rGen.next())
                    return .common(lElem, rElem)
                } else {
                    lOpt = lGen.next()
                    return .left(lElem)
                }
            case (nil, let rElem?):
                rOpt = rGen.next()
                return .right(rElem)
            case (let lElem?, nil):
                lOpt = lGen.next()
                return .left(lElem)
            case (nil, nil):
                return nil
            }
        }
    }
}

/// Support for sortedMerge()
enum MergeStep<LeftElement, RightElement> {
    /// An element only found in the left sequence:
    case left(LeftElement)
    /// An element only found in the right sequence:
    case right(RightElement)
    /// Left and right elements share a common key:
    case common(LeftElement, RightElement)
}
