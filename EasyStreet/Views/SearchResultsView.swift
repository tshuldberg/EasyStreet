import UIKit
import CoreLocation

protocol SearchResultsDelegate: AnyObject {
    func didSelectStreet(name: String, coordinate: CLLocationCoordinate2D)
}

final class SearchResultsView: UIView, UITableViewDataSource, UITableViewDelegate {

    weak var delegate: SearchResultsDelegate?

    private var results: [(streetName: String, coordinate: CLLocationCoordinate2D)] = []

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.layer.cornerRadius = 8
        tv.layer.borderWidth = 0.5
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.backgroundColor = .systemBackground
        return tv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true

        addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func update(with results: [(streetName: String, coordinate: CLLocationCoordinate2D)]) {
        self.results = results
        tableView.reloadData()
        isHidden = results.isEmpty
    }

    func clear() {
        results = []
        tableView.reloadData()
        isHidden = true
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = results[indexPath.row].streetName
        cell.textLabel?.font = .systemFont(ofSize: 14)
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let result = results[indexPath.row]
        delegate?.didSelectStreet(name: result.streetName, coordinate: result.coordinate)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        40
    }
}
