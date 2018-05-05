import MapKit
import GRDB
import RxGRDB

// A map annotation that wraps a place
final class PlaceAnnotation: NSObject, MKAnnotation {
    var place: Place {
        // Support MKMapView key-value observing on coordinates
        willSet { willChangeValue(forKey: "coordinate") }
        didSet { didChangeValue(forKey: "coordinate") }
    }
    
    @objc var coordinate: CLLocationCoordinate2D {
        return place.coordinate
    }
    
    init(place: Place) {
        self.place = place
    }
    
    func update(from row: Row) {
        self.place = Place(row: row)
    }
}

// Have PlaceAnnotation adopt FetchableRecord and PersistableRecord, so
// that it can feed PrimaryKeyDiffScanner:

extension PlaceAnnotation: FetchableRecord {
    convenience init(row: Row) {
        self.init(place: Place(row: row))
    }
}

extension PlaceAnnotation: PersistableRecord {
    static let databaseTableName = Place.databaseTableName
    
    func encode(to container: inout PersistenceContainer) {
        place.encode(to: &container)
    }
}
