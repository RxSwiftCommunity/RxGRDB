import UIKit
import MapKit
import GRDB
import RxGRDB
import RxSwift

// A "classic" ViewController
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
        try! Current.places().deleteAll()
    }
    
    @IBAction func refresh() {
        try! Current.places().refresh()
    }
    
    @IBAction func stressTest() {
        Current.places().stressTest()
    }
}

extension PlacesViewController: MKMapViewDelegate {
    
    // MARK: - Map View
    
    private func setupMapView() {
        Current.places().annotationDiff()
            .subscribe(onNext: { [weak self] diff in
                guard let self = self else { return }
                self.mapView.removeAnnotations(diff.deleted)
                self.mapView.addAnnotations(diff.inserted)
                self.zoomOnPlaces(animated: true)
            })
            .disposed(by: disposeBag)
    }
    
    private func zoomOnPlaces(animated: Bool) {
        // Turn all annotations into zero-sized map rects, that we will union
        // to build the zooming map rect.
        let rects = mapView.annotations.map { annotation in
            MKMapRect(
                origin: MKMapPoint(annotation.coordinate),
                size: MKMapSize(width: 0, height: 0))
        }
        
        // No rect => no annotation => no zoom
        guard let firstRect = rects.first else {
            return
        }
        
        // Union rects
        let zoomRect = rects
            .suffix(from: 1)
            .reduce(firstRect) { $0.union($1) }
        
        // Zoom
        mapView.setVisibleMapRect(
            zoomRect,
            edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
            animated: animated)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: "annotation") {
            return view
        }
        let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
        view.displayPriority = .required // opt out of clustering in order to show *all* annotations
        return view
    }
}
