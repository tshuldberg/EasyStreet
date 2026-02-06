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

    private let parkingCard = ParkingCardView()

    private let legendView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Properties

    private let streetRepo = StreetRepository.shared
    private let parkingRepo = ParkingRepository.shared
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocationCoordinate2D?
    private var parkedCarAnnotation: MKPointAnnotation?
    private var isAdjustingPin = false
    private var hasInitiallyLocated = false
    private var displayedSegmentIDs: Set<String> = []
    private var colorCache: [String: StreetSegment.MapColorStatus] = [:]
    private var overlayUpdateTimer: Timer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "EasyStreet"

        setupViews()
        setupMapView()
        setupSearchBar()
        setupLegendView()
        setupLocationManager()

        parkingCard.delegate = self

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
        view.addSubview(parkingCard)
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

            // Parking card at bottom
            parkingCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            parkingCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            parkingCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Legend view above parking card
            legendView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            legendView.bottomAnchor.constraint(equalTo: parkingCard.topAnchor, constant: -12),
            legendView.widthAnchor.constraint(equalToConstant: 120),
            legendView.heightAnchor.constraint(equalToConstant: 120)
        ])

        // Start in not-parked state
        parkingCard.configure(for: .notParked)
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

        // Set up tap gesture for street detail
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        tapGesture.require(toFail: longPressGesture)
        mapView.addGestureRecognizer(tapGesture)
    }

    private func setupSearchBar() {
        searchBar.delegate = self
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
        let redItem = createLegendItem(color: .systemRed, text: "Today")
        let orangeItem = createLegendItem(color: .systemOrange, text: "Tomorrow")
        let yellowItem = createLegendItem(color: .systemYellow, text: "2-3 Days")
        let greenItem = createLegendItem(color: .systemGreen, text: "Safe")

        stackView.addArrangedSubview(redItem)
        stackView.addArrangedSubview(orangeItem)
        stackView.addArrangedSubview(yellowItem)
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
        streetRepo.loadData { [weak self] success in
            guard let self = self, success else { return }

            // Add street segment overlays
            self.addStreetSegmentOverlays()
        }
    }

    private func addStreetSegmentOverlays() {
        // Delegate to the differential/throttled overlay updater
        updateMapOverlays()
    }

    private func updateMapOverlays() {
        let span = mapView.region.span

        // Don't render overlays when zoomed out too far (prevents 21K+ overlays)
        guard span.latitudeDelta < 0.05 else {
            let polylines = mapView.overlays.filter { $0 is MKPolyline }
            if !polylines.isEmpty {
                mapView.removeOverlays(polylines)
            }
            displayedSegmentIDs.removeAll()
            return
        }

        let visibleRect = mapView.visibleMapRect
        let visibleSegments = streetRepo.segments(in: visibleRect)
        let visibleIDs = Set(visibleSegments.map { $0.id })

        // Rebuild color cache for visible segments
        colorCache.removeAll(keepingCapacity: true)
        let today = Date()
        let cal = Calendar.current
        let upcomingDates: [(offset: Int, date: Date)] = (1...3).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (offset, d)
        }
        for segment in visibleSegments {
            colorCache[segment.id] = segment.mapColorStatus(today: today, upcomingDates: upcomingDates)
        }

        // Remove overlays no longer visible
        let toRemove = displayedSegmentIDs.subtracting(visibleIDs)
        if !toRemove.isEmpty {
            let overlaysToRemove = mapView.overlays.filter { overlay in
                if let polyline = overlay as? MKPolyline, let title = polyline.title {
                    return toRemove.contains(title)
                }
                return false
            }
            mapView.removeOverlays(overlaysToRemove)
        }

        // Add new overlays
        let toAdd = visibleIDs.subtracting(displayedSegmentIDs)
        if !toAdd.isEmpty {
            let newSegments = visibleSegments.filter { toAdd.contains($0.id) }
            for segment in newSegments {
                let polyline = segment.polyline
                polyline.title = segment.id
                mapView.addOverlay(polyline)
            }
        }

        displayedSegmentIDs = visibleIDs
    }

    // MARK: - Parked Car Management

    private func checkForParkedCar() {
        if parkingRepo.isCarParked, let location = parkingRepo.parkedLocation {
            // Add annotation for parked car
            addParkedCarAnnotation(at: location)

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

        if let streetName = parkingRepo.parkedStreetName {
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

    private func checkSweepingStatusForParkedCar() {
        guard let location = parkingRepo.parkedLocation else { return }

        SweepingRuleEngine.shared.analyzeSweeperStatus(for: location) { [weak self] status in
            DispatchQueue.main.async {
                self?.updateStatusDisplay(with: status)
            }
        }
    }

    private func updateStatusDisplay(with status: SweepingStatus) {
        let streetName = parkingRepo.parkedStreetName ?? "Unknown Street"

        switch status {
        case .noData:
            parkingCard.configure(for: .parked(
                streetName: streetName,
                statusText: "No sweeping data available",
                statusColor: .systemGray
            ))

        case .safe:
            parkingCard.configure(for: .parked(
                streetName: streetName,
                statusText: "Safe to park",
                statusColor: .systemGreen
            ))

        case .today(let time, let name):
            let timeString = formatTime(time)
            parkingCard.configure(for: .parked(
                streetName: name,
                statusText: "Sweeping today at \(timeString)",
                statusColor: .systemOrange
            ))
            parkingRepo.scheduleNotification(for: time, streetName: name)

        case .imminent(let time, let name):
            let timeString = formatTime(time)
            parkingCard.configure(for: .parked(
                streetName: name,
                statusText: "Sweeping imminent at \(timeString)!",
                statusColor: .systemRed
            ))
            parkingRepo.scheduleNotification(for: time, streetName: name)

        case .upcoming(let time, let name):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEE, MMM d"
            let dateString = dateFormatter.string(from: time)
            let timeString = formatTime(time)
            parkingCard.configure(for: .parked(
                streetName: name,
                statusText: "Next: \(dateString) at \(timeString)",
                statusColor: .systemBlue
            ))
            parkingRepo.scheduleNotification(for: time, streetName: name)

        case .unknown:
            parkingCard.configure(for: .parked(
                streetName: streetName,
                statusText: "Unable to determine status",
                statusColor: .systemGray
            ))
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

        // Get street name (async with geocoding fallback) and then save/update
        findStreetName(for: location) { [weak self] streetName in
            self?.parkingRepo.parkCar(at: location, streetName: streetName)
            self?.addParkedCarAnnotation(at: location)
            self?.checkSweepingStatusForParkedCar()
        }
    }

    @objc private func clearParkButtonTapped() {
        // Clear parked car data
        parkingRepo.clearParkedCar()

        // Remove annotation
        if let parkedAnnotation = parkedCarAnnotation {
            mapView.removeAnnotation(parkedAnnotation)
            parkedCarAnnotation = nil
        }

        // Update card
        parkingCard.configure(for: .notParked)
    }

    @objc private func parkedCarStatusChanged() {
        // Update UI when parked car status changes (called from NotificationCenter)
        if parkingRepo.isCarParked {
            // Car is parked
            if let location = parkingRepo.parkedLocation {
                addParkedCarAnnotation(at: location)
                checkSweepingStatusForParkedCar()
            }
        } else {
            // Car is not parked
            if let parkedAnnotation = parkedCarAnnotation {
                mapView.removeAnnotation(parkedAnnotation)
                parkedCarAnnotation = nil
            }
            parkingCard.configure(for: .notParked)
        }
    }

    @objc private func settingsTapped() {
        let current = parkingRepo.notificationLeadMinutes
        let alert = UIAlertController(
            title: "Notification Lead Time",
            message: "How far in advance should we notify you? Currently: \(current) minutes",
            preferredStyle: .actionSheet
        )
        for minutes in [15, 30, 60, 120] {
            let title = minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes > 60 ? "s" : "")"
            let style: UIAlertAction.Style = minutes == current ? .destructive : .default
            alert.addAction(UIAlertAction(title: title, style: style) { [weak self] _ in
                self?.parkingRepo.notificationLeadMinutes = minutes
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard parkingRepo.isCarParked, let parkedAnnotation = parkedCarAnnotation else { return }

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
                if let annotationView = mapView.view(for: parkedAnnotation) {
                    UIView.animate(withDuration: 0.2) {
                        annotationView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                        annotationView.alpha = 0.8
                    }
                }
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
            parkingRepo.updateParkedLocation(to: finalCoordinate)

            // Get street name (async with geocoding fallback) and update annotation
            findStreetName(for: finalCoordinate) { streetName in
                parkedAnnotation.subtitle = streetName
            }

            // Check sweeping status for new location
            checkSweepingStatusForParkedCar()

            if let annotationView = mapView.view(for: parkedAnnotation) {
                UIView.animate(withDuration: 0.2) {
                    annotationView.transform = .identity
                    annotationView.alpha = 1.0
                }
            }
            isAdjustingPin = false
        }
    }

    // MARK: - Map Tap → Street Detail

    @objc private func handleMapTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }

        let tapPoint = gestureRecognizer.location(in: mapView)
        let tapCoordinate = mapView.convert(tapPoint, toCoordinateFrom: mapView)
        let tapMapPoint = MKMapPoint(tapCoordinate)

        // Calculate hit-test threshold in meters based on zoom level
        let metersPerPixel = mapView.region.span.latitudeDelta * 111_000 / Double(mapView.bounds.height)
        let thresholdMeters = metersPerPixel * 30.0

        var closestPolyline: MKPolyline?
        var closestDistance = Double.greatestFiniteMagnitude

        for overlay in mapView.overlays {
            guard let polyline = overlay as? MKPolyline else { continue }

            let pointCount = polyline.pointCount
            guard pointCount >= 2 else { continue }

            let points = polyline.points()

            for i in 0..<(pointCount - 1) {
                let a = points[i]
                let b = points[i + 1]
                let dist = perpendicularDistance(from: tapMapPoint, toLineFrom: a, to: b)
                if dist < closestDistance {
                    closestDistance = dist
                    closestPolyline = polyline
                }
            }
        }

        // Convert closest distance to meters
        guard let polyline = closestPolyline, closestDistance < thresholdMeters else { return }

        guard let segmentID = polyline.title,
              let segment = streetRepo.segment(byID: segmentID) else { return }

        presentStreetDetail(for: segment)
    }

    /// Perpendicular distance from a point to a line segment, in meters.
    private func perpendicularDistance(from point: MKMapPoint, toLineFrom a: MKMapPoint, to b: MKMapPoint) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy

        guard lengthSq > 0 else {
            return point.distance(to: a)
        }

        // Project point onto line, clamping t to [0, 1]
        var t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSq
        t = max(0, min(1, t))

        let projection = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
        return point.distance(to: projection)
    }

    private func presentStreetDetail(for segment: StreetSegment) {
        let detailVC = StreetDetailViewController(segment: segment)
        detailVC.delegate = self

        if #available(iOS 15.0, *) {
            if let sheet = detailVC.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.prefersGrabberVisible = true
            }
            present(detailVC, animated: true)
        } else {
            detailVC.modalPresentationStyle = .pageSheet
            let nav = UINavigationController(rootViewController: detailVC)
            nav.navigationBar.topItem?.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(dismissPresentedSheet)
            )
            present(nav, animated: true)
        }
    }

    @objc private func dismissPresentedSheet() {
        dismiss(animated: true)
    }

    // MARK: - Helper Methods

    private func findStreetName(for coordinate: CLLocationCoordinate2D, completion: @escaping (String) -> Void) {
        // Try sweeping data first
        if let segment = streetRepo.findSegment(near: coordinate) {
            completion(segment.streetName)
            return
        }
        // Fallback to reverse geocoding
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            completion(placemarks?.first?.thoroughfare ?? "Unknown Street")
        }
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

            if let segmentID = polyline.title, let status = colorCache[segmentID] {
                switch status {
                case .red:
                    renderer.strokeColor = .systemRed
                case .orange:
                    renderer.strokeColor = .systemOrange
                case .yellow:
                    renderer.strokeColor = .systemYellow
                case .green:
                    renderer.strokeColor = .systemGreen
                }
            } else {
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
        overlayUpdateTimer?.invalidate()
        overlayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.updateMapOverlays()
        }
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
            let alert = UIAlertController(
                title: "Location Services Required",
                message: "EasyStreet needs your location to find nearby street sweeping schedules. Please enable location access in Settings.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last?.coordinate else { return }
        currentLocation = location

        // Only center map on first location fix
        if !hasInitiallyLocated {
            hasInitiallyLocated = true
            let region = MKCoordinateRegion(center: location,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.setRegion(region, animated: true)
        }

        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}

// MARK: - ParkingCardDelegate

extension MapViewController: ParkingCardDelegate {
    func parkingCardDidTapParkHere() {
        parkButtonTapped()
    }

    func parkingCardDidTapClearParking() {
        clearParkButtonTapped()
    }

    func parkingCardDidTapSettings() {
        settingsTapped()
    }
}

// MARK: - StreetDetailDelegate

extension MapViewController: StreetDetailDelegate {
    func streetDetailDidParkHere(at coordinate: CLLocationCoordinate2D, streetName: String) {
        parkingRepo.parkCar(at: coordinate, streetName: streetName)
        addParkedCarAnnotation(at: coordinate)
        checkSweepingStatusForParkedCar()
    }
}
