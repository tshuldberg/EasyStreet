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

    private let parkingCard = ParkingCardView()

    // MARK: - Toolbar Buttons

    private let legendButton = MapViewController.makeToolbarButton(systemName: "paintpalette.fill")
    private let searchButton = MapViewController.makeToolbarButton(systemName: "magnifyingglass")
    private let myLocationButton = MapViewController.makeToolbarButton(systemName: "location.fill")
    private let myCarButton = MapViewController.makeToolbarButton(systemName: "car.fill")

    // MARK: - Legend Popup

    private let legendPopup: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        view.isHidden = true
        return view
    }()

    // MARK: - Search Popup

    private let searchPopupContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        view.isHidden = true
        return view
    }()

    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search address"
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()

    // Dismiss overlay for popups
    private let popupDismissOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // Right-side button stack
    private let rightButtonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private static func makeToolbarButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.backgroundColor = .systemBackground
        button.tintColor = .systemBlue
        button.layer.cornerRadius = 20
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        return button
    }

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
    private var isLegendPopupVisible = false
    private var isSearchPopupVisible = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "EasyStreet"

        setupViews()
        setupMapView()
        setupToolbarButtons()
        setupLegendPopup()
        setupSearchPopup()
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
        view.addSubview(offlineBanner)
        view.addSubview(parkingCard)

        // Toolbar buttons
        view.addSubview(legendButton)
        view.addSubview(searchButton)
        view.addSubview(rightButtonStack)

        // Popup dismiss overlay (behind popups, catches outside taps)
        view.addSubview(popupDismissOverlay)

        // Popups (above dismiss overlay)
        view.addSubview(legendPopup)
        view.addSubview(searchPopupContainer)

        // Right button stack
        rightButtonStack.addArrangedSubview(myLocationButton)
        rightButtonStack.addArrangedSubview(myCarButton)
        myCarButton.isHidden = true // Only shown when car is parked

        NSLayoutConstraint.activate([
            // Map view takes the full screen
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Offline banner at top of safe area
            offlineBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            offlineBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Parking card at bottom
            parkingCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            parkingCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            parkingCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Legend button - bottom left above parking card
            legendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            legendButton.bottomAnchor.constraint(equalTo: parkingCard.topAnchor, constant: -12),

            // Search button - top right
            searchButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Right button stack - right side, above parking card
            rightButtonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            rightButtonStack.bottomAnchor.constraint(equalTo: parkingCard.topAnchor, constant: -12),

            // Popup dismiss overlay - full screen
            popupDismissOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            popupDismissOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            popupDismissOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            popupDismissOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        searchResultsView.delegate = self

        // Start in not-parked state
        parkingCard.configure(for: .notParked)

        // Attribution label
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

    private func setupToolbarButtons() {
        legendButton.addTarget(self, action: #selector(legendButtonTapped), for: .touchUpInside)
        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        myLocationButton.addTarget(self, action: #selector(myLocationButtonTapped), for: .touchUpInside)
        myCarButton.addTarget(self, action: #selector(myCarButtonTapped), for: .touchUpInside)

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissPopups))
        popupDismissOverlay.addGestureRecognizer(dismissTap)
    }

    private func setupLegendPopup() {
        let titleLabel = UILabel()
        titleLabel.text = "Map Legend"
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let items: [(UIColor, String)] = [
            (.systemRed, "Sweeping Today"),
            (.systemOrange, "Sweeping Tomorrow"),
            (.systemYellow, "Sweeping in 2-3 Days"),
            (.systemGreen, "Safe to Park")
        ]

        for (color, text) in items {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center

            let dot = UIView()
            dot.backgroundColor = color
            dot.layer.cornerRadius = 6
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 12),
                dot.heightAnchor.constraint(equalToConstant: 12)
            ])

            let label = UILabel()
            label.text = text
            label.font = UIFont.systemFont(ofSize: 13)

            row.addArrangedSubview(dot)
            row.addArrangedSubview(label)
            stackView.addArrangedSubview(row)
        }

        legendPopup.addSubview(titleLabel)
        legendPopup.addSubview(stackView)

        NSLayoutConstraint.activate([
            legendPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            legendPopup.bottomAnchor.constraint(equalTo: legendButton.topAnchor, constant: -8),
            legendPopup.widthAnchor.constraint(equalToConstant: 180),

            titleLabel.topAnchor.constraint(equalTo: legendPopup.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: legendPopup.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: legendPopup.trailingAnchor, constant: -14),

            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: legendPopup.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: legendPopup.trailingAnchor, constant: -14),
            stackView.bottomAnchor.constraint(equalTo: legendPopup.bottomAnchor, constant: -12)
        ])
    }

    private func setupSearchPopup() {
        searchBar.delegate = self

        searchPopupContainer.addSubview(searchBar)
        searchPopupContainer.addSubview(searchResultsView)

        NSLayoutConstraint.activate([
            searchPopupContainer.topAnchor.constraint(equalTo: searchButton.bottomAnchor, constant: 8),
            searchPopupContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchPopupContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            searchBar.topAnchor.constraint(equalTo: searchPopupContainer.topAnchor, constant: 4),
            searchBar.leadingAnchor.constraint(equalTo: searchPopupContainer.leadingAnchor, constant: 4),
            searchBar.trailingAnchor.constraint(equalTo: searchPopupContainer.trailingAnchor, constant: -4),

            searchResultsView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            searchResultsView.leadingAnchor.constraint(equalTo: searchPopupContainer.leadingAnchor, constant: 4),
            searchResultsView.trailingAnchor.constraint(equalTo: searchPopupContainer.trailingAnchor, constant: -4),
            searchResultsView.heightAnchor.constraint(lessThanOrEqualToConstant: 200),
            searchResultsView.bottomAnchor.constraint(lessThanOrEqualTo: searchPopupContainer.bottomAnchor, constant: -4),

            searchBar.bottomAnchor.constraint(lessThanOrEqualTo: searchPopupContainer.bottomAnchor, constant: -4)
        ])
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
        updateCarButtonVisibility()
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

    // MARK: - Toolbar Actions

    @objc private func legendButtonTapped() {
        if isLegendPopupVisible {
            dismissPopups()
        } else {
            dismissPopups()
            showLegendPopup()
        }
    }

    @objc private func searchButtonTapped() {
        if isSearchPopupVisible {
            dismissPopups()
        } else {
            dismissPopups()
            showSearchPopup()
        }
    }

    @objc private func myLocationButtonTapped() {
        guard let location = currentLocation else {
            // Request a fresh location fix
            locationManager.startUpdatingLocation()
            return
        }
        let region = MKCoordinateRegion(center: location,
                                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
        mapView.setRegion(region, animated: true)
    }

    @objc private func myCarButtonTapped() {
        guard let annotation = parkedCarAnnotation else { return }
        let region = MKCoordinateRegion(center: annotation.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005))
        mapView.setRegion(region, animated: true)
    }

    @objc private func dismissPopups() {
        if isLegendPopupVisible {
            isLegendPopupVisible = false
            UIView.animate(withDuration: 0.2, animations: {
                self.legendPopup.alpha = 0
            }, completion: { _ in
                self.legendPopup.isHidden = true
            })
        }
        if isSearchPopupVisible {
            isSearchPopupVisible = false
            searchBar.resignFirstResponder()
            searchResultsView.clear()
            UIView.animate(withDuration: 0.2, animations: {
                self.searchPopupContainer.alpha = 0
            }, completion: { _ in
                self.searchPopupContainer.isHidden = true
            })
        }
        popupDismissOverlay.isHidden = true
    }

    private func showLegendPopup() {
        isLegendPopupVisible = true
        popupDismissOverlay.isHidden = false
        legendPopup.isHidden = false
        legendPopup.alpha = 0
        UIView.animate(withDuration: 0.2) {
            self.legendPopup.alpha = 1
        }
    }

    private func showSearchPopup() {
        isSearchPopupVisible = true
        popupDismissOverlay.isHidden = false
        searchPopupContainer.isHidden = false
        searchPopupContainer.alpha = 0
        UIView.animate(withDuration: 0.2) {
            self.searchPopupContainer.alpha = 1
        }
        searchBar.becomeFirstResponder()
    }

    private func updateCarButtonVisibility() {
        myCarButton.isHidden = !parkingRepo.isCarParked
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
            self?.updateCarButtonVisibility()
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

        // Update card and car button
        parkingCard.configure(for: .notParked)
        updateCarButtonVisibility()
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
        updateCarButtonVisibility()
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
        guard let searchText = searchBar.text, !searchText.isEmpty else { return }

        // Try local search first
        let localResults = streetRepo.searchStreets(query: searchText)

        if localResults.count == 1 {
            // Single match: navigate directly and close popup
            dismissPopups()
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
                self.dismissPopups()
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
        dismissPopups()
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
        dismissPopups()
        searchBar.text = name
        let region = MKCoordinateRegion(center: coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.setRegion(region, animated: true)
    }
}
