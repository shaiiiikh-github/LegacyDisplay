# LegacyDisplay Security Model & Considerations

---

## 1. VNC Protocol Authentication (RFC 6143)

- **Authentication Mechanism**: Standard VNC Authentication (Type 2) uses a challenge-response scheme based on single DES.
- **DES Limitations**:
  - The password is limited to 8 characters (longer passwords are truncated).
  - Single DES is cryptographically weak by modern standards and subject to offline dictionary attacks if network packets are intercepted.
- **Deployment Recommendation**:
  - LegacyDisplay and the VNC server should be operated strictly on a **trusted, private local Wi-Fi network**.
  - Port 5900 should **never be exposed directly to the public Internet**.
  - If remote access over the Internet is required, route traffic through a secure WireGuard or OpenVPN tunnel, or an SSH port-forwarding tunnel.

---

## 2. On-Device Credential Storage

- **Keychain Only**: All VNC passwords entered by the user are stored exclusively in the iOS Keychain using `kSecClassGenericPassword` with `kSecAttrAccessibleAfterFirstUnlock`.
- **Prohibitions**:
  - Passwords are **never** stored in `UserDefaults`.
  - Passwords are **never** printed to system logs, console logs, or diagnostics views.
  - Passwords and private keys are **never** committed to version control.

---

## 3. Memory Safety & Network Input Validation

- **Bounded Dimensions**: ServerInit messages with desktop dimensions exceeding 4096 pixels in width or height are rejected immediately to protect against buffer overflows and memory exhaustion on the 1 GB iPad Air.
- **Bounded Rectangles**: Framebuffer updates containing more than 2048 rectangles per update are rejected.
- **Rectangle Bounds Checking**: All incoming update rectangles are bounds-checked against the desktop canvas before decoding into the framebuffer memory.
