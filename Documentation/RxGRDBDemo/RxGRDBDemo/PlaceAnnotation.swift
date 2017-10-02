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
}

// Have PlaceAnnotation adopt RowConvertible, Persistable, and Diffable, so
// that it can feed the `primaryKeySortedDiff` observable.

extension PlaceAnnotation: RowConvertible {
    convenience init(row: Row) {
        self.init(place: Place(row: row))
    }
}

extension PlaceAnnotation: Persistable {
    static let databaseTableName = Place.databaseTableName
    
    func encode(to container: inout PersistenceContainer) {
        place.encode(to: &container)
    }
}

extension PlaceAnnotation: Diffable {
    // The `primaryKeySortedDiff` observable documents that this method should
    // return self if we wish elements to be reused during the computation of
    // the diff.
    func updated(with row: Row) -> Self {
        place = Place(row: row)
        return self
    }
}
