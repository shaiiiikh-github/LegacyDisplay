import UIKit

/// Remote desktop session view controller (Section 7, 8, 9).
public final class RemoteDisplayViewController: UIViewController,
    RFBClientEngineDelegate, RFBNetworkSessionDelegate,
    InputHandlerDelegate, KeyboardManagerDelegate {

    public let host: String
    public let port: Int
    private let password: String

    private var engine: RFBClientEngine!
    private var session: RFBNetworkSession!
    private var inputHandler: InputHandler!
    private let keyboardManager = KeyboardManager()

    // MARK: - UI Components

    public let framebufferView: FramebufferView = {
        let view = FramebufferView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let topToolbar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.85)
        view.layer.cornerRadius = 8
        return view
    }()

    private let disconnectButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Disconnect", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        return btn
    }()

    private let keyboardButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("⌨ Keyboard", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        return btn
    }()

    private let sessionStatusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .lightGray
        label.text = "Connecting..."
        return label
    }()

    // Auxiliary Key Bar (Ctrl, Alt, Shift, Esc, Tab, Enter, Arrows, Shortcuts)
    private let auxiliaryKeyBar: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.backgroundColor = UIColor(white: 0.15, alpha: 0.95)
        sv.showsHorizontalScrollIndicator = false
        sv.isHidden = true
        return sv
    }()

    private let keyBarStackView: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.axis = .horizontal
        sv.spacing = 8
        sv.distribution = .fillProportionally
        return sv
    }()

    // Hidden text field for soft keyboard input
    private let hiddenTextField = UITextField(frame: .zero)

    // MARK: - Init & Lifecycle

    public init(host: String, port: Int, password: String) {
        self.host = host
        self.port = port
        self.password = password
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupEngineAndSession()
        startSession()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanupSession()
    }

    private func setupUI() {
        view.backgroundColor = .black

        view.addSubview(framebufferView)
        view.addSubview(topToolbar)
        topToolbar.addSubview(disconnectButton)
        topToolbar.addSubview(sessionStatusLabel)
        topToolbar.addSubview(keyboardButton)

        view.addSubview(auxiliaryKeyBar)
        auxiliaryKeyBar.addSubview(keyBarStackView)

        view.addSubview(hiddenTextField)
        hiddenTextField.isHidden = true

        inputHandler = InputHandler(targetView: framebufferView)
        inputHandler.delegate = self
        keyboardManager.delegate = self

        disconnectButton.addTarget(self, action: #selector(handleDisconnectTapped), for: .touchUpInside)
        keyboardButton.addTarget(self, action: #selector(handleKeyboardToggleTapped), for: .touchUpInside)

        setupAuxiliaryKeys()

        NSLayoutConstraint.activate([
            framebufferView.topAnchor.constraint(equalTo: view.topAnchor),
            framebufferView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            framebufferView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            framebufferView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            topToolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topToolbar.heightAnchor.constraint(equalToConstant: 40),
            topToolbar.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            topToolbar.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            disconnectButton.leadingAnchor.constraint(equalTo: topToolbar.leadingAnchor, constant: 12),
            disconnectButton.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),

            sessionStatusLabel.leadingAnchor.constraint(equalTo: disconnectButton.trailingAnchor, constant: 16),
            sessionStatusLabel.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),

            keyboardButton.leadingAnchor.constraint(equalTo: sessionStatusLabel.trailingAnchor, constant: 16),
            keyboardButton.trailingAnchor.constraint(equalTo: topToolbar.trailingAnchor, constant: -12),
            keyboardButton.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),

            auxiliaryKeyBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            auxiliaryKeyBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            auxiliaryKeyBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            auxiliaryKeyBar.heightAnchor.constraint(equalToConstant: 44),

            keyBarStackView.topAnchor.constraint(equalTo: auxiliaryKeyBar.topAnchor, constant: 4),
            keyBarStackView.bottomAnchor.constraint(equalTo: auxiliaryKeyBar.bottomAnchor, constant: -4),
            keyBarStackView.leadingAnchor.constraint(equalTo: auxiliaryKeyBar.leadingAnchor, constant: 8),
            keyBarStackView.trailingAnchor.constraint(equalTo: auxiliaryKeyBar.trailingAnchor, constant: -8)
        ])
    }

    private func setupAuxiliaryKeys() {
        let keys: [(title: String, action: Selector)] = [
            ("Esc", #selector(handleEscKey)),
            ("Tab", #selector(handleTabKey)),
            ("Ctrl", #selector(handleCtrlKey)),
            ("Alt", #selector(handleAltKey)),
            ("Shift", #selector(handleShiftKey)),
            ("←", #selector(handleLeftKey)),
            ("↑", #selector(handleUpKey)),
            ("↓", #selector(handleDownKey)),
            ("→", #selector(handleRightKey)),
            ("Ctrl+Alt+T", #selector(handleTerminalShortcut)),
            ("Ctrl+C", #selector(handleCopyShortcut)),
            ("Ctrl+V", #selector(handlePasteShortcut))
        ]

        for item in keys {
            let btn = UIButton(type: .system)
            btn.setTitle(item.title, for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = UIColor(white: 0.25, alpha: 1.0)
            btn.layer.cornerRadius = 6
            btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            btn.addTarget(self, action: item.action, for: .touchUpInside)
            keyBarStackView.addArrangedSubview(btn)
        }
    }

    private func setupEngineAndSession() {
        engine = RFBClientEngine(password: password, sharedDesktop: true)
        engine.delegate = self

        session = RFBNetworkSession()
        session.delegate = self
    }

    private func startSession() {
        sessionStatusLabel.text = "Connecting to \(host)..."
        engine.startConnecting(host: host, port: port)
        session.connect(toHost: host, port: port)
    }

    private func cleanupSession() {
        inputHandler.releaseAllButtons()
        keyboardManager.releaseAllModifiers()
        session.disconnect()
        engine.disconnect()
    }

    // MARK: - Actions

    @objc private func handleDisconnectTapped() {
        cleanupSession()
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleKeyboardToggleTapped() {
        if auxiliaryKeyBar.isHidden {
            auxiliaryKeyBar.isHidden = false
            hiddenTextField.becomeFirstResponder()
        } else {
            auxiliaryKeyBar.isHidden = true
            hiddenTextField.resignFirstResponder()
        }
    }

    @objc private func handleEscKey() { keyboardManager.sendKeyPress(keySym: KeyboardManager.KeySym.escape) }
    @objc private func handleTabKey() { keyboardManager.sendKeyPress(keySym: KeyboardManager.KeySym.tab) }
    @objc private func handleCtrlKey() { _ = keyboardManager.toggleCtrl() }
    @objc private func handleAltKey() { _ = keyboardManager.toggleAlt() }
    @objc private func handleShiftKey() { _ = keyboardManager.toggleShift() }
    @objc private func handleLeftKey() { keyboardManager.sendKeyPress(keySym: KeyboardManager.KeySym.left) }
    @objc private func handleRightKey() { keyboardManager.sendKeyPress(keySym: KeyboardManager.KeySym.right) }
    @objc private func handleUpKey() { keyboardManager.sendKeyPress(keySym: KeyboardManager.KeySym.up) }
    @objc private func handleDownKey() { keyboardManager.sendKeyPress(keySym: KeyboardManager.KeySym.down) }
    @objc private func handleTerminalShortcut() { keyboardManager.sendShortcut("Ctrl+Alt+T") }
    @objc private func handleCopyShortcut() { keyboardManager.sendShortcut("Ctrl+C") }
    @objc private func handlePasteShortcut() { keyboardManager.sendShortcut("Ctrl+V") }

    // MARK: - RFBClientEngineDelegate

    public func rfbEngine(_ engine: RFBClientEngine, didChangeState state: RFBConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sessionStatusLabel.text = state.description
            if state.isConnected {
                self.sessionStatusLabel.textColor = .green
            }
        }
    }

    public func rfbEngine(_ engine: RFBClientEngine, didReceiveServerInit serverInit: RFBServerInit) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.framebufferView.updateDesktopDimensions(
                width: Int(serverInit.framebufferWidth),
                height: Int(serverInit.framebufferHeight)
            )
        }
    }

    public func rfbEngine(_ engine: RFBClientEngine, didUpdateFramebufferRect x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let rect = CGRect(x: Int(x), y: Int(y), width: Int(width), height: Int(height))
            self.framebufferView.updateBuffer(from: engine.framebuffer, dirtyRect: rect)
        }
    }

    public func rfbEngine(_ engine: RFBClientEngine, didChangeDesktopSize width: UInt16, height: UInt16) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.framebufferView.updateDesktopDimensions(width: Int(width), height: Int(height))
        }
    }

    public func rfbEngine(_ engine: RFBClientEngine, didEncounterError error: RFBConnectionError) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sessionStatusLabel.textColor = .red
            self.sessionStatusLabel.text = "Error"
            
            let alert = UIAlertController(
                title: "VNC Connection Failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }))
            self.present(alert, animated: true)
        }
    }

    public func rfbEngine(_ engine: RFBClientEngine, sendData data: Data) {
        session.send(data: data)
    }

    // MARK: - RFBNetworkSessionDelegate

    public func networkSessionDidConnect(_ session: RFBNetworkSession) {
        // TCP connected; RFB server will send ProtocolVersion
    }

    public func networkSession(_ session: RFBNetworkSession, didReceiveData data: Data) {
        engine.processIncomingData(data)
    }

    public func networkSession(_ session: RFBNetworkSession, didFailWithError error: Error) {
        engine.processIncomingData(Data())
        rfbEngine(engine, didEncounterError: .networkError(error.localizedDescription))
    }

    public func networkSessionDidClose(_ session: RFBNetworkSession) {
        rfbEngine(engine, didEncounterError: .connectionClosedByServer)
    }

    // MARK: - InputHandlerDelegate

    public func inputHandler(_ handler: InputHandler, sendPointerEvent buttonMask: UInt8, x: UInt16, y: UInt16) {
        engine.sendPointerEvent(buttonMask: buttonMask, x: x, y: y)
    }

    // MARK: - KeyboardManagerDelegate

    public func keyboardManager(_ manager: KeyboardManager, sendKeyEvent down: Bool, keySym: UInt32) {
        engine.sendKeyEvent(down: down, keySym: keySym)
    }
}
