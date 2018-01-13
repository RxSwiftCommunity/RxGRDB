import UIKit
import MapKit
import RxGRDB
import RxSwift

class PlacesViewController: UIViewController {
    private let disposeBag = DisposeBag()
    
    @IBOutlet private var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupMapView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        zoomOnPlaces(animated: false)
    }
}

extension PlacesViewController {
    
    // MARK: - Actions
    
    private func setupToolbar() {
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlaces)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
    
    @IBAction func deletePlaces() {
        try! dbPool.writeInTransaction { db in
            try Place.deleteAll(db)
            return .commit
        }
    }
    
    @IBAction func refresh() {
        try! dbPool.writeInTransaction { db in
            if try Place.fetchCount(db) == 0 {
                // Insert places
                for _ in 0..<8 {
                    var place = Place(id: nil, coordinate: Place.randomCoordinate())
                    try place.insert(db)
                }
            } else {
                // Insert a place
                if arc4random_uniform(2) == 0 {
                    var place = Place(id: nil, coordinate: Place.randomCoordinate())
                    try place.insert(db)
                }
                // Delete a random place
                if arc4random_uniform(2) == 0 {
                    try Place.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some places
                for place in try Place.fetchAll(db) where arc4random_uniform(2) == 0 {
                    var place = place
                    place.latitude += 0.001 * (Double(arc4random()) / Double(UInt32.max) - 0.5)
                    place.longitude += 0.001 * (Double(arc4random()) / Double(UInt32.max) - 0.5)
                    try place.update(db)
                }
            }
            return .commit
        }
    }
    
    @IBAction func stressTest() {
        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            self.refresh()
        }
    }
}

extension PlacesViewController {
    
    // MARK: - Map View
    
    private func setupMapView() {
        // Feed the map view from annotations fetched from the database.
        //
        // To efficiently update the map view as database content changes, we
        // use the primaryKeySortedDiff observable. It requires the database
        // request to be sorted by primary key:
        let placeAnnotations = PlaceAnnotation.order(Place.Columns.id)
        
        placeAnnotations.rx
            .primaryKeySortedDiff(in: dbPool)
            .subscribe(onNext: { [weak self] (diff) in
                guard let strongSelf = self else { return }
                
                // Remove deleted annotation
                strongSelf.mapView.removeAnnotations(diff.deleted)
                
                // Add inserted annotation
                strongSelf.mapView.addAnnotations(diff.inserted)
                
                // Update updated annotations. This triggers key-value observing
                // notifications on the annotation coordinates. It is important
                // that those KVO notifications happens on the main thread, or
                // the map view would complain.
                for (oldPlace, newPlace) in diff.updated {
                    oldPlace.update(from: newPlace)
                }
                
                strongSelf.zoomOnPlaces(animated: true)
            })
            .disposed(by: disposeBag)
    }
    
    private func zoomOnPlaces(animated: Bool) {
        // Turn all annotations into zero-sized map rects, that we will union
        // to build the zooming map rect.
        let rects = mapView.annotations.map { annotation in
            MKMapRect(
                origin: MKMapPointForCoordinate(annotation.coordinate),
                size: MKMapSize(width: 0, height: 0))
        }
        
        // No rect => no annotation => no zoom
        guard let firstRect = rects.first else {
            return
        }
        
        // Union rects
        let zoomRect = rects
            .suffix(from: 1)
            .reduce(firstRect) { MKMapRectUnion($0, $1) }
        
        // Zoom
        mapView.setVisibleMapRect(
            zoomRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            animated: animated)
    }
}
