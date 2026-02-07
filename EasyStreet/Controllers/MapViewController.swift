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
    private var colorCacheDay: Int = -1
    private var overlayUpdateTimer: Timer?
    private var lastOverlayUpdate: Date?
    private var rendererLogCount = 0
    private let offlineBanner = OfflineBannerView()
    private let searchResultsView = SearchResultsView()
    private var searchDebounceTimer: Timer?

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectivityChanged),
            name: .connectivityDidChange,
            object: nil
        )

        // Add info button to navigation bar
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain, target: self, action: #selector(infoTapped)
        )

        // Show disclaimer on first launch
        if !DisclaimerManager.hasSeenDisclaimer {
            showDisclaimer(isFirstLaunch: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Update map overlay colors based on current time
        updateMapOverlays()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if displayedSegmentIDs.isEmpty {
            #if DEBUG
            print("[EasyStreet] viewDidAppear: no overlays, forcing refresh")
            #endif
            updateMapOverlays()
        }
    }

    /// Public refresh entry point for SceneDelegate and other external callers.
    /// Refreshes map overlay colors based on the current time.
    func refreshMapDisplay() {
        updateMapOverlays()
    }

    // MARK: - Setup Methods

    private func setupViews() {
        view.addSubview(mapView)
        view.addSubview(searchBar)
        view.addSubview(offlineBanner)
        view.addSubview(searchResultsView)
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

            // Offline banner below search bar
            offlineBanner.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            offlineBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Search results below search bar
            searchResultsView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            searchResultsView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchResultsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            searchResultsView.heightAnchor.constraint(lessThanOrEqualToConstant: 200),

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

        searchResultsView.delegate = self

        // Start in not-parked state
        parkingCard.configure(for: .notParked)

        // Attribution label (Task 7)
        let attributionLabel = UILabel()
        attributionLabel.text = DisclaimerManager.attributionText
        attributionLabel.font = UIFont.systemFont(ofSize: 9)
        attributionLabel.textColor = .secondaryLabel
        attributionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(attributionLabel)

        NSLayoutConstraint.activate([
            attributionLabel.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -4),
            attributionLabel.centerXAnchor.constraint(equalTo: mapView.centerXAnchor)
        ])
    }

    private func setupMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true

        // Set initial region to San Francisco
        let sfCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let region = MKCoordinateRegion(center: sfCoordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))
        mapView.setRegion(region, animated: false)

        // Set up gesture recognizer for pin adjustment
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        mapView.addGestureRecognizer(longPressGesture)

        // Set up tap gesture for street detail
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        tapGesture.require(toFail: longPressGesture)
        tapGesture.delegate = self
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
        #if DEBUG
        print("[EasyStreet] loadStreetSweepingData: starting")
        #endif
        streetRepo.loadData { [weak self] success in
            #if DEBUG
            print("[EasyStreet] loadStreetSweepingData: completion, success=\(success)")
            #endif
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
        #if DEBUG
        print("[EasyStreet] updateMapOverlays: span=\(span.latitudeDelta)")
        #endif

        // Don't render overlays when zoomed out too far (prevents 21K+ overlays)
        guard span.latitudeDelta < 0.05 else {
            #if DEBUG
            print("[EasyStreet] updateMapOverlays: SKIPPED, zoomed out (span=\(span.latitudeDelta))")
            #endif
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

        // Day-based color cache invalidation: only clear when the calendar day changes
        let today = Date()
        let cal = Calendar.current
        let currentDay = cal.ordinality(of: .day, in: .year, for: today) ?? 0
        if currentDay != colorCacheDay {
            colorCache.removeAll(keepingCapacity: true)
            colorCacheDay = currentDay
        }
        let upcomingDates: [(offset: Int, date: Date)] = (1...3).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: today) else { return nil }
            return (offset, d)
        }
        for segment in visibleSegments where colorCache[segment.id] == nil {
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

        // Add new overlays — encode color directly on the polyline via subtitle
        // so rendererFor can read it without depending on the colorCache timing
        let toAdd = visibleIDs.subtracting(displayedSegmentIDs)
        if !toAdd.isEmpty {
            let newSegments = visibleSegments.filter { toAdd.contains($0.id) }
            for segment in newSegments {
                let polyline = segment.polyline
                polyline.title = segment.id
                switch colorCache[segment.id] ?? .green {
                case .red: polyline.subtitle = "red"
                case .orange: polyline.subtitle = "orange"
                case .yellow: polyline.subtitle = "yellow"
                case .green: polyline.subtitle = "green"
                }
                mapView.addOverlay(polyline, level: .aboveLabels)
            }

            #if DEBUG
            // Log sample polyline details for first 3 new overlays
            for segment in newSegments.prefix(3) {
                let pl = segment.polyline
                print("[EasyStreet] sample overlay: id=\(segment.id), coords=\(segment.coordinates.count), polyline.pointCount=\(pl.pointCount)")
            }
            #endif
        }

        #if DEBUG
        print("[EasyStreet] updateMapOverlays: \(visibleSegments.count) visible, +\(toAdd.count)/-\(toRemove.count), total overlays=\(mapView.overlays.count)")
        #endif

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

        guard let polyline = MapHitTesting.findClosestPolyline(
            tapMapPoint: tapMapPoint,
            overlays: mapView.overlays,
            thresholdMeters: thresholdMeters
        ) else { return }

        guard let segmentID = polyline.title,
              let segment = streetRepo.segment(byID: segmentID) else { return }

        presentStreetDetail(for: segment)
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
        // Offline: skip network geocoding
        guard ConnectivityMonitor.shared.isConnected else {
            completion("Unknown Street")
            return
        }
        // Fallback to reverse geocoding
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            completion(placemarks?.first?.thoroughfare ?? "Unknown Street")
        }
    }

    @objc private func connectivityChanged() {
        if ConnectivityMonitor.shared.isConnected {
            offlineBanner.hide()
        } else {
            offlineBanner.show()
        }
    }

    @objc private func infoTapped() {
        showDisclaimer(isFirstLaunch: false)
    }

    private func showDisclaimer(isFirstLaunch: Bool) {
        var message = DisclaimerManager.disclaimerBody
        if let buildDate = streetRepo.dataBuildDate {
            message += "\n\nStreet data last updated: \(buildDate)"
        }
        let alert = UIAlertController(
            title: DisclaimerManager.disclaimerTitle,
            message: message,
            preferredStyle: .alert
        )
        if isFirstLaunch {
            alert.addAction(UIAlertAction(title: "I Understand", style: .default) { _ in
                DisclaimerManager.markDisclaimerSeen()
            })
        } else {
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        }
        present(alert, animated: true)
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
            renderer.lineWidth = 4
            renderer.alpha = 0.85

            #if DEBUG
            // Log first few renderer calls
            if rendererLogCount < 5 {
                rendererLogCount += 1
                print("[EasyStreet] rendererFor: title=\(polyline.title ?? "nil"), subtitle=\(polyline.subtitle ?? "nil"), points=\(polyline.pointCount)")
            }
            #endif

            // Read color from subtitle (set at polyline creation time) — avoids cache timing issues
            switch polyline.subtitle {
            case "red":
                renderer.strokeColor = .systemRed
            case "orange":
                renderer.strokeColor = .systemOrange
            case "yellow":
                renderer.strokeColor = .systemYellow
            case "green":
                renderer.strokeColor = .systemGreen
            default:
                // Fallback: try the cache, then gray
                if let segmentID = polyline.title, let status = colorCache[segmentID] {
                    switch status {
                    case .red: renderer.strokeColor = .systemRed
                    case .orange: renderer.strokeColor = .systemOrange
                    case .yellow: renderer.strokeColor = .systemYellow
                    case .green: renderer.strokeColor = .systemGreen
                    }
                } else {
                    renderer.strokeColor = .systemGray
                }
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

        // Throttle: update immediately if ≥300ms since last update, otherwise schedule trailing update
        let now = Date()
        if lastOverlayUpdate == nil || now.timeIntervalSince(lastOverlayUpdate!) >= 0.3 {
            lastOverlayUpdate = now
            updateMapOverlays()
        } else {
            overlayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.lastOverlayUpdate = Date()
                self?.updateMapOverlays()
            }
        }
    }
}

// MARK: - UISearchBarDelegate

extension MapViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchDebounceTimer?.invalidate()
        guard !searchText.isEmpty else {
            searchResultsView.clear()
            return
        }
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let results = self.streetRepo.searchStreets(query: searchText)
            self.searchResultsView.update(with: results)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchResultsView.clear()

        guard let searchText = searchBar.text, !searchText.isEmpty else { return }

        // Try local search first
        let localResults = streetRepo.searchStreets(query: searchText)

        if localResults.count == 1 {
            // Single match: navigate directly
            let result = localResults[0]
            let region = MKCoordinateRegion(center: result.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            mapView.setRegion(region, animated: true)
        } else if localResults.count > 1 {
            // Multiple matches: show dropdown
            searchResultsView.update(with: localResults)
        } else if ConnectivityMonitor.shared.isConnected {
            // No local results, online: fall back to geocoder
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(searchText) { [weak self] placemarks, error in
                guard let self = self else { return }
                if let error = error {
                    self.showAlert(title: "Search Error", message: error.localizedDescription)
                    return
                }
                guard let placemark = placemarks?.first,
                      let location = placemark.location?.coordinate else {
                    self.showAlert(title: "Not Found", message: "Could not find that address.")
                    return
                }
                let region = MKCoordinateRegion(center: location,
                                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                self.mapView.setRegion(region, animated: true)
            }
        } else {
            // No local results, offline
            showAlert(title: "Not Found", message: "No matching streets found. Connect to the internet to search addresses outside our database.")
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchResultsView.clear()
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
        #if DEBUG
        print("Location manager error: \(error.localizedDescription)")
        #endif
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

// MARK: - UIGestureRecognizerDelegate

extension MapViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our tap gesture to fire alongside MKMapView's internal gestures
        if gestureRecognizer is UITapGestureRecognizer {
            return true
        }
        return false
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

// MARK: - SearchResultsDelegate

extension MapViewController: SearchResultsDelegate {
    func didSelectStreet(name: String, coordinate: CLLocationCoordinate2D) {
        searchResultsView.clear()
        searchBar.resignFirstResponder()
        searchBar.text = name
        let region = MKCoordinateRegion(center: coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.setRegion(region, animated: true)
    }
}
