import Dispatch
import GRDB
import RxGRDB
import RxSwift

/// Places is responsible for high-level operations on the places database.
struct Places {
    fileprivate let database: DatabaseWriter
    
    init(database: DatabaseWriter) {
        self.database = database
    }
    
    // MARK: - Modify Players
    
    func deleteAll() throws {
        try database.write { db in
            _ = try Place.deleteAll(db)
        }
    }
    
    func refresh() throws {
        try database.write { db in
            if try Player.fetchCount(db) == 0 {
                // Insert new random players
                for _ in 0..<8 {
                    var place = Place(id: nil, coordinate: Place.randomCoordinate())
                    try place.insert(db)
                }
            } else {
                // Insert a player
                if Bool.random() {
                    var place = Place(id: nil, coordinate: Place.randomCoordinate())
                    try place.insert(db)
                }
                // Delete a random player
                if Bool.random() {
                    try Place.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some players
                for var place in try Place.fetchAll(db) where Bool.random() {
                    try place.updateChanges(db) {
                        $0.latitude += 0.001 * (Double(arc4random()) / Double(UInt32.max) - 0.5)
                        $0.longitude += 0.001 * (Double(arc4random()) / Double(UInt32.max) - 0.5)
                    }
                }
            }
        }
    }
    
    func stressTest() {
        for _ in 0..<50 {
            DispatchQueue.global().async {
                try? self.refresh()
            }
        }
    }
    
    /// An observable that tracks changes in the Hall of Fame
    func annotationDiff() -> Observable<PrimaryKeyDiff<PlaceAnnotation>> {
        // Feed the map view from annotations fetched from the database.
        //
        // To efficiently update the map view as database content changes, we
        // use PrimaryKeyDiffScanner. It requires the tracked database request
        // to be sorted by primary key:
        let placeAnnotations = PlaceAnnotation.orderByPrimaryKey()
        
        let diffScanner = try! database.read { db in
            try PrimaryKeyDiffScanner(
                database: db,
                request: placeAnnotations,
                initialRecords: [],
                updateRecord: { (annotation, row) in
                    // When an annotation is modified in the databse, we want to
                    // update the existing annotation instance.
                    //
                    // This avoids the visual glitches that would happen if
                    // we would update the map view by removing old annotations
                    // and adding new ones.
                    annotation.update(from: row)
                    return annotation
            })
        }
        
        return placeAnnotations
            .asRequest(of: Row.self)
            .rx
            .observeAll(in: database)
            .scan(diffScanner) { (diffScanner, rows) in diffScanner.diffed(from: rows) }
            .map { $0.diff }
    }
}
