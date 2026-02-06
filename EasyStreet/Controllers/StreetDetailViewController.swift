import Foundation
import UIKit
import CoreLocation
import MapKit

// MARK: - Delegate Protocol

protocol StreetDetailDelegate: AnyObject {
    func streetDetailDidParkHere(at coordinate: CLLocationCoordinate2D, streetName: String)
}

// MARK: - StreetDetailViewController

class StreetDetailViewController: UIViewController {

    // MARK: - Properties

    let segment: StreetSegment
    weak var delegate: StreetDetailDelegate?

    // MARK: - UI Elements

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let streetNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let nextSweepingLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let divider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, *) {
            view.backgroundColor = .separator
        } else {
            view.backgroundColor = .lightGray
        }
        return view
    }()

    private let scheduleHeaderLabel: UILabel = {
        let label = UILabel()
        label.text = "Weekly Schedule"
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let rulesStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let parkHereButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Park Here", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Initialization

    init(segment: StreetSegment) {
        self.segment = segment
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupLayout()
        configureContent()
    }

    // MARK: - Layout

    private func setupLayout() {
        let padding: CGFloat = 16

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(streetNameLabel)
        contentView.addSubview(nextSweepingLabel)
        contentView.addSubview(divider)
        contentView.addSubview(scheduleHeaderLabel)
        contentView.addSubview(rulesStackView)
        contentView.addSubview(parkHereButton)

        parkHereButton.addTarget(self, action: #selector(parkHereTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // Scroll view fills the entire view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content view matches scroll view edges and width
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Street name label
            streetNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            streetNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            streetNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),

            // Next sweeping label
            nextSweepingLabel.topAnchor.constraint(equalTo: streetNameLabel.bottomAnchor, constant: 8),
            nextSweepingLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            nextSweepingLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),

            // Divider
            divider.topAnchor.constraint(equalTo: nextSweepingLabel.bottomAnchor, constant: padding),
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            divider.heightAnchor.constraint(equalToConstant: 1),

            // Schedule header
            scheduleHeaderLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: padding),
            scheduleHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            scheduleHeaderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),

            // Rules stack view
            rulesStackView.topAnchor.constraint(equalTo: scheduleHeaderLabel.bottomAnchor, constant: 8),
            rulesStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            rulesStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),

            // Park Here button
            parkHereButton.topAnchor.constraint(equalTo: rulesStackView.bottomAnchor, constant: 24),
            parkHereButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            parkHereButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            parkHereButton.heightAnchor.constraint(equalToConstant: 44),
            parkHereButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
        ])
    }

    // MARK: - Content Configuration

    private func configureContent() {
        // Street name
        streetNameLabel.text = segment.streetName

        // Next sweeping status
        configureNextSweepingLabel()

        // Rules list
        configureRulesList()
    }

    private func configureNextSweepingLabel() {
        let status = segment.mapColorStatus()

        switch status {
        case .red:
            let timeText = sweepingTimeText(for: Date())
            nextSweepingLabel.text = "Sweeping today at \(timeText)"
            nextSweepingLabel.textColor = .systemRed

        case .orange:
            let calendar = Calendar.current
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
                let timeText = sweepingTimeText(for: tomorrow)
                nextSweepingLabel.text = "Sweeping tomorrow at \(timeText)"
            } else {
                nextSweepingLabel.text = "Sweeping tomorrow"
            }
            nextSweepingLabel.textColor = .systemOrange

        case .yellow:
            let (nextDate, _) = segment.nextSweeping()
            if let nextDate = nextDate {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "EEE, MMM d"
                let dateString = dateFormatter.string(from: nextDate)

                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                let timeString = timeFormatter.string(from: nextDate)

                nextSweepingLabel.text = "Next sweeping: \(dateString) at \(timeString)"
            } else {
                nextSweepingLabel.text = "Sweeping scheduled within 2-3 days"
            }
            nextSweepingLabel.textColor = .label

        case .green:
            nextSweepingLabel.text = "No sweeping scheduled soon"
            nextSweepingLabel.textColor = .systemGreen
        }
    }

    /// Find the start time of the first applicable rule for the given date.
    private func sweepingTimeText(for date: Date) -> String {
        for rule in segment.rules {
            if rule.appliesTo(date: date) {
                return rule.formattedTimeRange
            }
        }
        return ""
    }

    private func configureRulesList() {
        // Remove any existing arranged subviews
        rulesStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if segment.rules.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No sweeping rules on file"
            emptyLabel.font = UIFont.systemFont(ofSize: 15)
            emptyLabel.textColor = .secondaryLabel
            rulesStackView.addArrangedSubview(emptyLabel)
            return
        }

        for rule in segment.rules {
            let ruleLabel = UILabel()
            ruleLabel.font = UIFont.systemFont(ofSize: 15)
            ruleLabel.numberOfLines = 0
            ruleLabel.text = "\(rule.dayName)  \(rule.formattedTimeRange)  (\(rule.weeksDescription))"
            rulesStackView.addArrangedSubview(ruleLabel)
        }
    }

    // MARK: - Actions

    @objc private func parkHereTapped() {
        guard !segment.coordinates.isEmpty else { return }

        let midIndex = segment.coordinates.count / 2
        let midCoord = segment.coordinates[midIndex]

        guard midCoord.count >= 2 else { return }

        let coordinate = CLLocationCoordinate2D(latitude: midCoord[0], longitude: midCoord[1])
        delegate?.streetDetailDidParkHere(at: coordinate, streetName: segment.streetName)
        dismiss(animated: true)
    }
}
