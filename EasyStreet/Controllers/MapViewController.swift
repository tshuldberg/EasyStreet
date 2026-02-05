import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController {
    
    // MARK: - UI Properties
    
    private let mapView: MKMapView = {
        let map = MKMapView()
        map.translatesAutoresizingMaskIntoConstraints = false
        return map
    }()
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search address"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let parkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("I Parked Here", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let clearParkButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear Parked Car", for: .normal)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Initially hidden until car is parked
        return button
    }()
    
    private let statusView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true // Initially hidden until car is parked
        return view
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let legendView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Properties
    
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    private var parkedCarAnnotation: MKPointAnnotation?
    private var isAdjustingPin = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        title = "EasyStreet"
        
        setupViews()
        setupMapView()
        setupSearchBar()
        setupButtons()
        setupStatusView()
        setupLegendView()
        setupLocationManager()
        
        // Load street sweeping data
        loadStreetSweepingData()
        
        // Check if we have a previously parked car
        checkForParkedCar()
        
        // Register for parked car status change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(parkedCarStatusChanged),
            name: .parkedCarStatusDidChange,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Update map overlay colors based on current time
        updateMapOverlays()
    }
    
    // MARK: - Setup Methods
    
    private func setupViews() {
        view.addSubview(mapView)
        view.addSubview(searchBar)
        view.addSubview(parkButton)
        view.addSubview(clearParkButton)
        view.addSubview(statusView)
        view.addSubview(legendView)
        
        NSLayoutConstraint.activate([
            // Map view takes the full screen
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Search bar at top
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            
            // Park button at bottom
            parkButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            parkButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            parkButton.widthAnchor.constraint(equalToConstant: 200),
            parkButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Clear parked car button just above park button
            clearParkButton.bottomAnchor.constraint(equalTo: parkButton.topAnchor, constant: -10),
            clearParkButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            clearParkButton.widthAnchor.constraint(equalToConstant: 200),
            clearParkButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Status view above the buttons
            statusView.bottomAnchor.constraint(equalTo: clearParkButton.topAnchor, constant: -20),
            statusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusView.widthAnchor.constraint(equalToConstant: 300),
            
            // Legend view in bottom left
            legendView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            legendView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            legendView.widthAnchor.constraint(equalToConstant: 100),
            legendView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        
        // Set initial region to San Francisco
        let sfCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let region = MKCoordinateRegion(center: sfCoordinate, 
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        mapView.setRegion(region, animated: false)
        
        // Set up gesture recognizer for pin adjustment
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        mapView.addGestureRecognizer(longPressGesture)
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
    }
    
    private func setupButtons() {
        parkButton.addTarget(self, action: #selector(parkButtonTapped), for: .touchUpInside)
        clearParkButton.addTarget(self, action: #selector(clearParkButtonTapped), for: .touchUpInside)
    }
    
    private func setupStatusView() {
        statusView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: statusView.topAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: statusView.leadingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: statusView.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: statusView.bottomAnchor, constant: -10)
        ])
    }
    
    private func setupLegendView() {
        // Create a stack view for legend items
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        legendView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: legendView.topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: legendView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: legendView.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: legendView.bottomAnchor, constant: -8)
        ])
        
        // Add legend items
        let redItem = createLegendItem(color: .systemRed, text: "Sweeping Today")
        let greenItem = createLegendItem(color: .systemGreen, text: "No Sweeping Today")
        
        stackView.addArrangedSubview(redItem)
        stackView.addArrangedSubview(greenItem)
    }
    
    private func createLegendItem(color: UIColor, text: String) -> UIView {
        let container = UIView()
        
        let colorView = UIView()
        colorView.backgroundColor = color
        colorView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 10)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(colorView)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            colorView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            colorView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorView.widthAnchor.constraint(equalToConstant: 10),
            colorView.heightAnchor.constraint(equalToConstant: 10),
            
            label.leadingAnchor.constraint(equalTo: colorView.trailingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        
        return container
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Request location permission
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Data Loading
    
    private func loadStreetSweepingData() {
        StreetSweepingDataManager.shared.loadData { [weak self] success in
            guard let self = self, success else { return }
            
            // Add street segment overlays
            self.addStreetSegmentOverlays()
        }
    }
    
    private func addStreetSegmentOverlays() {
        // Get visible map area
        let visibleRect = mapView.visibleMapRect
        
        // Get segments for the visible area
        let segments = StreetSweepingDataManager.shared.segments(in: visibleRect)
        
        // Add polylines for each segment
        for segment in segments {
            let polyline = segment.polyline
            
            // Store the segment ID in the polyline's title for lookup
            polyline.title = segment.id
            
            mapView.addOverlay(polyline)
        }
    }
    
    private func updateMapOverlays() {
        // This would refresh the colors of existing overlays
        // For MVP, we'll just remove and re-add them
        mapView.removeOverlays(mapView.overlays)
        addStreetSegmentOverlays()
    }
    
    // MARK: - Parked Car Management
    
    private func checkForParkedCar() {
        if ParkedCarManager.shared.isCarParked, let location = ParkedCarManager.shared.parkedLocation {
            // Add annotation for parked car
            addParkedCarAnnotation(at: location)
            
            // Update UI for parked state
            updateUIForParkedState()
            
            // Check sweeping status for parked location
            checkSweepingStatusForParkedCar()
        }
    }
    
    private func addParkedCarAnnotation(at location: CLLocationCoordinate2D) {
        // Remove existing annotation if any
        if let existingAnnotation = parkedCarAnnotation {
            mapView.removeAnnotation(existingAnnotation)
        }
        
        // Create new annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = location
        annotation.title = "My Car"
        
        if let streetName = ParkedCarManager.shared.parkedStreetName {
            annotation.subtitle = streetName
        }
        
        // Add to map
        mapView.addAnnotation(annotation)
        parkedCarAnnotation = annotation
        
        // Center map on parked car
        let region = MKCoordinateRegion(center: location, 
                                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
        mapView.setRegion(region, animated: true)
    }
    
    private func updateUIForParkedState() {
        parkButton.isHidden = true
        clearParkButton.isHidden = false
        statusView.isHidden = false
    }
    
    private func updateUIForUnparkedState() {
        parkButton.isHidden = false
        clearParkButton.isHidden = true
        statusView.isHidden = true
    }
    
    private func checkSweepingStatusForParkedCar() {
        guard let location = ParkedCarManager.shared.parkedLocation else { return }
        
        SweepingRuleEngine.shared.analyzeSweeperStatus(for: location) { [weak self] status in
            DispatchQueue.main.async {
                self?.updateStatusDisplay(with: status)
            }
        }
    }
    
    private func updateStatusDisplay(with status: SweepingStatus) {
        switch status {
        case .noData:
            statusLabel.text = "No sweeping data available for this location."
            statusView.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.9)
            
        case .safe:
            statusLabel.text = "No street sweeping scheduled. You're safe to park here."
            statusView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
            
        case .today(let time, let streetName):
            let timeString = formatTime(time)
            statusLabel.text = "⚠️ Street sweeping TODAY at \(timeString) on \(streetName). Remember to move your car!"
            statusView.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
            
            // Schedule notification
            ParkedCarManager.shared.scheduleNotification(for: time, streetName: streetName)
            
        case .imminent(let time, let streetName):
            let timeString = formatTime(time)
            statusLabel.text = "🚨 URGENT: Street sweeping in less than 1 hour at \(timeString) on \(streetName). Move your car NOW!"
            statusView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
            
            // Schedule notification (if not already scheduled)
            ParkedCarManager.shared.scheduleNotification(for: time, streetName: streetName)
            
        case .upcoming(let time, let streetName):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, MMM d"
            let dateString = dateFormatter.string(from: time)
            let timeString = formatTime(time)
            
            statusLabel.text = "Next street sweeping: \(dateString) at \(timeString) on \(streetName)."
            statusView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
            
            // Schedule notification
            ParkedCarManager.shared.scheduleNotification(for: time, streetName: streetName)
            
        case .unknown:
            statusLabel.text = "Could not determine street sweeping schedule. Check local signs."
            statusView.backgroundColor = UIColor.systemGray.withAlphaComponent(0.9)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    // MARK: - Action Handlers
    
    @objc private func parkButtonTapped() {
        guard let location = locationManager.location?.coordinate else {
            showAlert(title: "Location Unavailable", message: "Please enable location services to use this feature.")
            return
        }
        
        // Get street name if possible
        let streetName = findStreetName(for: location) ?? "Unknown Street"
        
        // Save parked location
        ParkedCarManager.shared.parkCar(at: location, streetName: streetName)
        
        // Add annotation to map
        addParkedCarAnnotation(at: location)
        
        // Update UI
        updateUIForParkedState()
        
        // Check sweeping status
        checkSweepingStatusForParkedCar()
    }
    
    @objc private func clearParkButtonTapped() {
        // Clear parked car data
        ParkedCarManager.shared.clearParkedCar()
        
        // Remove annotation
        if let parkedAnnotation = parkedCarAnnotation {
            mapView.removeAnnotation(parkedAnnotation)
            parkedCarAnnotation = nil
        }
        
        // Update UI
        updateUIForUnparkedState()
    }
    
    @objc private func parkedCarStatusChanged() {
        // Update UI when parked car status changes (called from NotificationCenter)
        if ParkedCarManager.shared.isCarParked {
            // Car is parked
            if let location = ParkedCarManager.shared.parkedLocation {
                addParkedCarAnnotation(at: location)
                updateUIForParkedState()
                checkSweepingStatusForParkedCar()
            }
        } else {
            // Car is not parked
            if let parkedAnnotation = parkedCarAnnotation {
                mapView.removeAnnotation(parkedAnnotation)
                parkedCarAnnotation = nil
            }
            updateUIForUnparkedState()
        }
    }
    
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard ParkedCarManager.shared.isCarParked, let parkedAnnotation = parkedCarAnnotation else { return }
        
        if gestureRecognizer.state == .began {
            // Start pin adjustment
            let touchPoint = gestureRecognizer.location(in: mapView)
            let touchCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            // Check if the touch is near the parked car annotation
            let touchMapPoint = MKMapPoint(touchCoordinate)
            let annotationMapPoint = MKMapPoint(parkedAnnotation.coordinate)
            
            let distance = touchMapPoint.distance(to: annotationMapPoint)
            if distance < 500 { // Threshold in map points
                isAdjustingPin = true
            }
        } else if gestureRecognizer.state == .changed && isAdjustingPin {
            // Update pin location
            let touchPoint = gestureRecognizer.location(in: mapView)
            let newCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            parkedAnnotation.coordinate = newCoordinate
        } else if gestureRecognizer.state == .ended && isAdjustingPin {
            // Finish adjustment
            let touchPoint = gestureRecognizer.location(in: mapView)
            let finalCoordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            // Update saved location
            ParkedCarManager.shared.updateParkedLocation(to: finalCoordinate)
            
            // Get street name if possible
            let streetName = findStreetName(for: finalCoordinate) ?? "Unknown Street"
            
            // Update annotation subtitle
            parkedAnnotation.subtitle = streetName
            
            // Check sweeping status for new location
            checkSweepingStatusForParkedCar()
            
            isAdjustingPin = false
        }
    }
    
    // MARK: - Helper Methods
    
    private func findStreetName(for coordinate: CLLocationCoordinate2D) -> String? {
        // In MVP, we can just use the segment's street name
        if let segment = StreetSweepingDataManager.shared.findSegment(near: coordinate) {
            return segment.streetName
        }
        return nil
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - MKMapViewDelegate

extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.lineWidth = 5
            
            // Get segment for this polyline
            if let segmentID = polyline.title,
               let segment = StreetSweepingDataManager.shared.segments(in: mapView.visibleMapRect)
                .first(where: { $0.id == segmentID }) {
                
                // Color based on today's sweeping status
                if segment.hasSweeperToday() {
                    renderer.strokeColor = .systemRed
                } else {
                    renderer.strokeColor = .systemGreen
                }
            } else {
                // Default color
                renderer.strokeColor = .systemGray
            }
            
            return renderer
        }
        
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        // Handle selection of annotations (e.g., showing more details about the parked car)
        guard let annotation = view.annotation else { return }
        
        // If it's a parked car annotation
        if annotation === parkedCarAnnotation {
            // Show status info
            checkSweepingStatusForParkedCar()
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Custom view for our parked car annotation
        if annotation === parkedCarAnnotation {
            let identifier = "parkedCar"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            let markerView = annotationView as? MKMarkerAnnotationView
            markerView?.markerTintColor = .systemBlue
            markerView?.glyphImage = UIImage(systemName: "car.fill")
            
            return annotationView
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // When map region changes, update the displayed street segments
        // For efficient rendering in larger datasets
        updateMapOverlays()
    }
}

// MARK: - UISearchBarDelegate

extension MapViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            return
        }
        
        // Geocode the address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchText) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showAlert(title: "Geocoding Error", message: error.localizedDescription)
                return
            }
            
            guard let placemark = placemarks?.first,
                  let location = placemark.location?.coordinate else {
                self.showAlert(title: "Location Not Found", message: "Could not find the address.")
                return
            }
            
            // Center map on the location
            let region = MKCoordinateRegion(center: location, 
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            self.mapView.setRegion(region, animated: true)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension MapViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            mapView.showsUserLocation = true
        case .denied, .restricted:
            showAlert(title: "Location Access Denied", 
                     message: "Please enable location services in Settings to use all features.")
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last?.coordinate else { return }
        
        // Save the current location
        currentLocation = location
        
        // Only center map on user if they haven't moved it themselves
        if !mapView.isUserInteractionEnabled {
            let region = MKCoordinateRegion(center: location, 
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.setRegion(region, animated: true)
        }
        
        // We don't need continuous updates for this app
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
} 