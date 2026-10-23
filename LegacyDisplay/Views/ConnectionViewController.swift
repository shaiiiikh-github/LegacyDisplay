import UIKit

public final class ConnectionViewController: UIViewController {

    // MARK: - UI Components

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

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "LegacyDisplay"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = .black
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Wireless Raspberry Pi Desktop for iPad"
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textAlignment = .center
        label.textColor = .darkGray
        return label
    }()

    private let formContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.96, alpha: 1.0)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        return view
    }()

    public let hostTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Host / IP Address (e.g. 192.168.1.100)"
        tf.borderStyle = .roundedRect
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.keyboardType = .numbersAndPunctuation
        tf.clearButtonMode = .whileEditing
        return tf
    }()

    public let portTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "Port (default 5900)"
        tf.text = "5900"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .numberPad
        return tf
    }()

    public let passwordTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.placeholder = "VNC Password (if required)"
        tf.borderStyle = .roundedRect
        tf.isSecureTextEntry = true
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        return tf
    }()

    public let connectButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Connect to Desktop", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        btn.layer.cornerRadius = 8
        return btn
    }()

    public let activityIndicator: UIActivityIndicatorView = {
        let ai: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            ai = UIActivityIndicatorView(style: .medium)
        } else {
            ai = UIActivityIndicatorView(style: .gray)
        }
        ai.translatesAutoresizingMaskIntoConstraints = false
        ai.hidesWhenStopped = true
        return ai
    }()

    public let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Ready to connect"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    public let diagnosticsView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isEditable = false
        tv.font = UIFont(name: "Menlo-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12)
        tv.textColor = .darkGray
        tv.backgroundColor = UIColor(white: 0.94, alpha: 1.0)
        tv.layer.cornerRadius = 8
        tv.layer.borderWidth = 1
        tv.layer.borderColor = UIColor(white: 0.85, alpha: 1.0).cgColor
        tv.text = "Diagnostics:\n- RFB 3.8 / VNC Auth (Type 2) Supported\n- iOS 12.0+ Native Stack Ready"
        return tv
    }()

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedProfile()
    }

    private func setupUI() {
        title = "LegacyDisplay"
        view.backgroundColor = .white

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(formContainer)

        formContainer.addSubview(hostTextField)
        formContainer.addSubview(portTextField)
        formContainer.addSubview(passwordTextField)
        formContainer.addSubview(connectButton)
        formContainer.addSubview(activityIndicator)
        formContainer.addSubview(statusLabel)

        contentView.addSubview(diagnosticsView)

        connectButton.addTarget(self, action: #selector(handleConnect), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            formContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            formContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            formContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            formContainer.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            formContainer.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),

            hostTextField.topAnchor.constraint(equalTo: formContainer.topAnchor, constant: 20),
            hostTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: 20),
            hostTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -20),
            hostTextField.heightAnchor.constraint(equalToConstant: 44),

            portTextField.topAnchor.constraint(equalTo: hostTextField.bottomAnchor, constant: 14),
            portTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: 20),
            portTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -20),
            portTextField.heightAnchor.constraint(equalToConstant: 44),

            passwordTextField.topAnchor.constraint(equalTo: portTextField.bottomAnchor, constant: 14),
            passwordTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: 20),
            passwordTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -20),
            passwordTextField.heightAnchor.constraint(equalToConstant: 44),

            connectButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 20),
            connectButton.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: 20),
            connectButton.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -20),
            connectButton.heightAnchor.constraint(equalToConstant: 48),

            activityIndicator.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 16),
            activityIndicator.centerXAnchor.constraint(equalTo: formContainer.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -20),
            statusLabel.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor, constant: -20),

            diagnosticsView.topAnchor.constraint(equalTo: formContainer.bottomAnchor, constant: 24),
            diagnosticsView.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor),
            diagnosticsView.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor),
            diagnosticsView.heightAnchor.constraint(equalToConstant: 120),
            diagnosticsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func loadSavedProfile() {
        let profiles = ProfileStorage.loadProfiles()
        if let first = profiles.first {
            hostTextField.text = first.host
            portTextField.text = String(first.port)
            if let savedPw = KeychainManager.shared.getPassword(forHost: first.host, port: first.port) {
                passwordTextField.text = savedPw
            }
        }
    }

    @objc private func handleConnect() {
        view.endEditing(true)

        guard let host = hostTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else {
            showError("Host / IP address is required.")
            return
        }

        let port = Int(portTextField.text ?? "") ?? 5900
        guard port >= 1 && port <= 65535 else {
            showError("Port must be between 1 and 65535.")
            return
        }

        let password = passwordTextField.text ?? ""

        // Save profile and keychain password securely
        let profile = ConnectionProfile(host: host, port: port)
        ProfileStorage.saveProfile(profile)
        if !password.isEmpty {
            KeychainManager.shared.savePassword(password, forHost: host, port: port)
        }

        // Navigate to Remote Desktop session
        let remoteVC = RemoteDisplayViewController(host: host, port: port, password: password)
        navigationController?.pushViewController(remoteVC, animated: true)
    }

    private func showError(_ message: String) {
        statusLabel.text = message
        statusLabel.textColor = .red
        let alert = UIAlertController(title: "Connection Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
