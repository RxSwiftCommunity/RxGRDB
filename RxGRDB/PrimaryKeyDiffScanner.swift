#if USING_SQLCIPHER
    import GRDBCipher
#else
    import GRDB
#endif
import RxSwift

/// TODO
public struct PrimaryKeyDiffScanner<Element: RowConvertible & MutablePersistable> {
    private let primaryKey: (Row) -> RowValue
    private let updateElement: (Element, Row) -> Element
    private let references: [Reference]
    
    /// TODO
    public let diff: PrimaryKeyDiff<Element>
    
    private struct Reference {
        let primaryKey: RowValue // Allows to sort elements by primary key
        let row: Row             // Allows to identify identical elements
        let element: Element     // An element reference
    }
    
    /// TODO
    public init<Request>(
        database: Database,
        request: Request,
        initialElements: [Element],
        updateElement: ((Element, Row) -> Element)? = nil)
        throws
        where Request: TypedRequest, Request.RowDecoder == Element
    {
        let primaryKey = try request.primaryKey(database)
        let references = initialElements.map { element -> Reference in
            let row = Row(element.databaseDictionary)
            return Reference(
                primaryKey: primaryKey(row),
                row: row,
                element: element)
        }
        self.init(
            primaryKey: primaryKey,
            updateElement: updateElement ?? { (_, row) in Element(row: row) },
            references: references,
            diff: PrimaryKeyDiff(inserted: [], updated: [], deleted: []))
    }
        
    private init(
        primaryKey: @escaping (Row) -> RowValue,
        updateElement: @escaping (Element, Row) -> Element,
        references: [Reference],
        diff: PrimaryKeyDiff<Element>)
    {
        self.primaryKey = primaryKey
        self.updateElement = updateElement
        self.references = references
        self.diff = diff
    }

    public func diffed(from rows: [Row]) -> PrimaryKeyDiffScanner {
        let primaryKey = self.primaryKey
        let newElements = rows.map { (primaryKey: primaryKey($0), row: $0) }

        var inserted: [Element] = []
        var updated: [Element] = []
        var deleted: [Element] = []
        var nextReferences: [Reference] = []

        let mergeSteps = sortedMerge(
            left: references,
            right: newElements,
            leftKey: { $0.primaryKey },
            rightKey: { $0.primaryKey })
        for step in mergeSteps {
            switch step {
            case .left(let previous):
                // Deletion
                deleted.append(previous.element)
            case .common(let previous, let new):
                // Update
                if new.row == previous.row {
                    nextReferences.append(previous)
                } else {
                    let newElement = updateElement(previous.element, new.row)
                    updated.append(newElement)
                    nextReferences.append(Reference(primaryKey: previous.primaryKey, row: new.row, element: newElement))
                }
            case .right(let new):
                // Insertion
                let element = Element(row: new.row)
                inserted.append(element)
                nextReferences.append(Reference(primaryKey: new.primaryKey, row: new.row, element: element))
            }
        }
        
        let diff = PrimaryKeyDiff(
            inserted: inserted,
            updated: updated,
            deleted: deleted)
        
        return PrimaryKeyDiffScanner(
            primaryKey: primaryKey,
            updateElement: updateElement,
            references: nextReferences,
            diff: diff)
    }
}

public struct PrimaryKeyDiff<Element> {
    public let inserted: [Element]
    public let updated: [Element]
    public let deleted: [Element]
    
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

