import UIKit

// MARK: - Delegate Protocol

protocol ParkingCardDelegate: AnyObject {
    func parkingCardDidTapParkHere()
    func parkingCardDidTapClearParking()
    func parkingCardDidTapSettings()
}

// MARK: - Card State

enum ParkingCardState {
    case notParked
    case parked(streetName: String, statusText: String, statusColor: UIColor)
}

// MARK: - ParkingCardView

class ParkingCardView: UIView {

    // MARK: - Properties

    weak var delegate: ParkingCardDelegate?

    // MARK: - Not Parked State UI

    private let parkHereButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("I Parked Here", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Parked State UI

    private let streetNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusTextLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let clearParkingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear Parking", for: .normal)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        let gearImage = UIImage(systemName: "gear")
        button.setImage(gearImage, for: .normal)
        button.tintColor = .gray
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let bottomStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Containers for State Management

    private let notParkedContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let parkedContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCard()
        setupNotParkedState()
        setupParkedState()
        setupActions()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCard()
        setupNotParkedState()
        setupParkedState()
        setupActions()
    }

    // MARK: - Setup

    private func setupCard() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: -2)
        layer.shadowRadius = 8
    }

    private func setupNotParkedState() {
        addSubview(notParkedContainer)
        notParkedContainer.addSubview(parkHereButton)

        NSLayoutConstraint.activate([
            notParkedContainer.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            notParkedContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            notParkedContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            notParkedContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            parkHereButton.topAnchor.constraint(equalTo: notParkedContainer.topAnchor),
            parkHereButton.leadingAnchor.constraint(equalTo: notParkedContainer.leadingAnchor),
            parkHereButton.trailingAnchor.constraint(equalTo: notParkedContainer.trailingAnchor),
            parkHereButton.bottomAnchor.constraint(equalTo: notParkedContainer.bottomAnchor),
            parkHereButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupParkedState() {
        addSubview(parkedContainer)

        parkedContainer.addSubview(streetNameLabel)
        parkedContainer.addSubview(statusTextLabel)
        parkedContainer.addSubview(bottomStack)

        bottomStack.addArrangedSubview(clearParkingButton)
        bottomStack.addArrangedSubview(settingsButton)

        NSLayoutConstraint.activate([
            parkedContainer.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            parkedContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            parkedContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            parkedContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            streetNameLabel.topAnchor.constraint(equalTo: parkedContainer.topAnchor),
            streetNameLabel.leadingAnchor.constraint(equalTo: parkedContainer.leadingAnchor),
            streetNameLabel.trailingAnchor.constraint(equalTo: parkedContainer.trailingAnchor),

            statusTextLabel.topAnchor.constraint(equalTo: streetNameLabel.bottomAnchor, constant: 4),
            statusTextLabel.leadingAnchor.constraint(equalTo: parkedContainer.leadingAnchor),
            statusTextLabel.trailingAnchor.constraint(equalTo: parkedContainer.trailingAnchor),

            bottomStack.topAnchor.constraint(equalTo: statusTextLabel.bottomAnchor, constant: 12),
            bottomStack.leadingAnchor.constraint(equalTo: parkedContainer.leadingAnchor),
            bottomStack.trailingAnchor.constraint(equalTo: parkedContainer.trailingAnchor),
            bottomStack.bottomAnchor.constraint(equalTo: parkedContainer.bottomAnchor),

            settingsButton.widthAnchor.constraint(equalToConstant: 44),
            settingsButton.heightAnchor.constraint(equalToConstant: 44),

            clearParkingButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Let the clear parking button stretch to fill remaining width
        clearParkingButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        settingsButton.setContentHuggingPriority(.required, for: .horizontal)
        settingsButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func setupActions() {
        parkHereButton.addTarget(self, action: #selector(parkHereTapped), for: .touchUpInside)
        clearParkingButton.addTarget(self, action: #selector(clearParkingTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
    }

    // MARK: - Public API

    func configure(for state: ParkingCardState) {
        switch state {
        case .notParked:
            notParkedContainer.isHidden = false
            parkedContainer.isHidden = true

        case .parked(let streetName, let statusText, let statusColor):
            notParkedContainer.isHidden = true
            parkedContainer.isHidden = false
            streetNameLabel.text = streetName
            statusTextLabel.text = statusText
            statusTextLabel.textColor = statusColor
        }
    }

    // MARK: - Actions

    @objc private func parkHereTapped() {
        delegate?.parkingCardDidTapParkHere()
    }

    @objc private func clearParkingTapped() {
        delegate?.parkingCardDidTapClearParking()
    }

    @objc private func settingsTapped() {
        delegate?.parkingCardDidTapSettings()
    }
}
