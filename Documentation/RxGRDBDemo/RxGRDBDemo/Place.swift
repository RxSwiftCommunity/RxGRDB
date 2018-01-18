import CoreLocation
import MapKit
import GRDB

// A place
struct Place: Codable {
    var id: Int64?
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    init(id: Int64?, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

// Define colums so that we can build GRDB requests
extension Place {
    enum Columns {
        static let id = Column("id")
    }
}

// Adopt RowConvertible so that we can fetch places from the database.
// Implementation is automatically derived from Codable.
extension Place: RowConvertible { }

// Adopt MutablePersistable so that we can create/update/delete places in the database.
// Implementation is partially derived from Codable.
extension Place: MutablePersistable {
    static let databaseTableName = "places"
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// Support for place randomization
extension Place {
    static func randomCoordinate() -> CLLocationCoordinate2D {
        let paris = CLLocationCoordinate2D(latitude: 48.8534100, longitude: 2.3488000)
        return CLLocationCoordinate2D.random(withinDistance: 8000, from: paris)
    }
}

extension CLLocationCoordinate2D {
    static func random(withinDistance distance: CLLocationDistance, from center: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        func randomDouble() -> Double {
            return Double(arc4random()) / Double(UInt32.max)
        }
        
        let d = sqrt(randomDouble()) * distance
        let angle = randomDouble() * 2 * .pi
        let latitudinalMeters = d * cos(angle)
        let longitudinalMeters = d * sin(angle)
        let region = MKCoordinateRegionMakeWithDistance(center, latitudinalMeters, longitudinalMeters)
        return CLLocationCoordinate2D(
            latitude: center.latitude + copysign(region.span.latitudeDelta, latitudinalMeters),
            longitude: center.longitude + copysign(region.span.longitudeDelta, longitudinalMeters))
    }
}

