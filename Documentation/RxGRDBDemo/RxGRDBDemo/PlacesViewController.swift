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
    
    // MARK: - Toolbar
    
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
                    let coordinate = Place.randomCoordinate()
                    var place = Place(id: nil, latitude: coordinate.latitude, longitude: coordinate.longitude)
                    try place.insert(db)
                }
            } else {
                // Insert a place
                if arc4random_uniform(2) == 0 {
                    let coordinate = Place.randomCoordinate()
                    var place = Place(id: nil, latitude: coordinate.latitude, longitude: coordinate.longitude)
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
        let placeAnnotations = PlaceAnnotation.order(Place.Columns.id)
        placeAnnotations.rx
            .primaryKeySortedDiff(in: dbPool)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] (diff) in
                guard let strongSelf = self else { return }
                strongSelf.mapView.removeAnnotations(diff.deleted)
                strongSelf.mapView.addAnnotations(diff.inserted)
                strongSelf.zoomOnPlaces(animated: true)
            })
        .disposed(by: disposeBag)
    }
    
    private func zoomOnPlaces(animated: Bool) {
        let annotations = mapView.annotations
        guard let first = annotations.first else {
            return
        }
        
        func rect(_ coordinate: CLLocationCoordinate2D) -> MKMapRect {
            return MKMapRect(
                origin: MKMapPointForCoordinate(coordinate),
                size: MKMapSize(width: 0, height: 0))
        }
        
        let initialMapRect = rect(first.coordinate)
        let fittingMapRect = annotations
            .suffix(from: 1)
            .reduce(initialMapRect) { mapRect, annotation in
                MKMapRectUnion(mapRect, rect(annotation.coordinate))
        }
        
        mapView.setVisibleMapRect(
            fittingMapRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            animated: animated)
    }
}
