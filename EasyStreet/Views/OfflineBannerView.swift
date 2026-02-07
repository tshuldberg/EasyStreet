import UIKit

final class OfflineBannerView: UIView {

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "wifi.slash"))
        iv.tintColor = .white
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let label: UILabel = {
        let l = UILabel()
        l.text = "Offline – Sweeping data available. Map tiles may be limited."
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        l.numberOfLines = 1
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.8
        return l
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
        backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true

        addSubview(iconView)
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func show(animated: Bool = true) {
        guard isHidden else { return }
        isHidden = false
        if animated {
            alpha = 0
            UIView.animate(withDuration: 0.3) { self.alpha = 1 }
        }
    }

    func hide(animated: Bool = true) {
        guard !isHidden else { return }
        if animated {
            UIView.animate(withDuration: 0.3, animations: { self.alpha = 0 }) { _ in
                self.isHidden = true
                self.alpha = 1
            }
        } else {
            isHidden = true
        }
    }
}
