import UIKit

public class ViewController: UIViewController {

    public let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "LegacyDisplay"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()

    public let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Native Swift/UIKit Initialized"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()

    public let displayCardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    public let cardContentLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Display Target Ready"
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.textColor = .tertiaryLabel
        return label
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "LegacyDisplay"

        view.addSubview(titleLabel)
        view.addSubview(statusLabel)
        view.addSubview(displayCardView)
        displayCardView.addSubview(cardContentLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            displayCardView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 32),
            displayCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            displayCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            displayCardView.heightAnchor.constraint(equalToConstant: 200),

            cardContentLabel.centerXAnchor.constraint(equalTo: displayCardView.centerXAnchor),
            cardContentLabel.centerYAnchor.constraint(equalTo: displayCardView.centerYAnchor)
        ])
    }
}
