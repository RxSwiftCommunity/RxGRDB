import MapKit
import GRDB
import RxGRDB

final class PlaceAnnotation: NSObject, MKAnnotation {
    var place: Place {
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

extension PlaceAnnotation: RowConvertible {
    convenience init(row: Row) {
        self.init(place: Place(row: row))
    }
}

extension PlaceAnnotation: Persistable {
    static var databaseTableName: String {
        return Place.databaseTableName
    }
    
    func encode(to container: inout PersistenceContainer) {
        place.encode(to: &container)
    }
}

extension PlaceAnnotation: Diffable {
    func updated(with row: Row) -> Self {
        place = Place(row: row)
        return self
    }
}
