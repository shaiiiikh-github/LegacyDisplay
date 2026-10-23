# LegacyDisplay Architecture & Engineering Specifications

Native iOS remote display and touch control client for iPad Air (1st Generation) targeting Raspberry Pi OS / Debian desktop.

---

## 1. Environment & Target Specifications

- **Target Device**: iPad Air (1st Generation, Model A1474).
- **SoC & Architecture**: Apple A7 (ARM64 dual-core @ 1.4 GHz), 1 GB LPDDR3 RAM.
- **Operating System**: iOS 12.5.8.
- **Deployment Target**: iOS 12.0 (Strictly enforced: no SwiftUI, Combine, CryptoKit, async/await, Swift Concurrency, or UIScene).
- **Display Resolution**: 2048 x 1536 @ 264 ppi (Retina), standard 4:3 aspect ratio.

---

## 2. Real Server Probe Findings

A real network protocol probe was executed from the developer machine to the Raspberry Pi test server (`172.21.238.234:5900`) using `tools/rfb_probe.py`:

```
Probe Execution:
- Target: 172.21.238.234:5900
- Server Greeting: RFB 005.000 (RealVNC proprietary server)
- Client Handshake: RFB 003.008 (RFC 6143 standard fallback)
- Advertised Security Types: [13, 5]
  * Type 13: RealVNC proprietary encryption
  * Type 5: RA2 (RealVNC RSA-AES)
- Standard Type 2 (VNC Authentication): Not advertised in current server configuration.
- Standard Type 1 (None): Not advertised.
```

### Architectural Decision:
1. When the server only offers proprietary types (such as Types 13 and 5), the client will not attempt unverified proprietary crypto. Instead, it transitions to `.failed(.unsupportedSecurityMode)` with clear diagnostic instructions to enable "VNC password" (Type 2) on the server.
2. The client implements full RFC 6143 Type 2 (DES challenge-response VNC Authentication) using an independent, pure-Swift DES engine.
3. A local mock server (`tools/mock_rfb_server.py`) is provided for automated testing of Type 1 and Type 2 handshakes and framebuffer streams.

---

## 3. System Architecture & Components

```
+---------------------------------------------------------------------------------+
|                                 LegacyDisplay                                   |
|                                                                                 |
|  +---------------------------+       +---------------------------------------+  |
|  | ConnectionViewController  | ----> |      RemoteDisplayViewController      |  |
|  +---------------------------+       +---------------------------------------+  |
|               |                                  |               |              |
|               v                                  v               v              |
|  +---------------------------+       +-----------------+ +-------------------+  |
|  |     ProfileStorage /      |       |  InputHandler   | |  KeyboardManager  |  |
|  |      KeychainManager      |       | (Multi-touch)   | |  (Auxiliary Bar)  |  |
|  +---------------------------+       +-----------------+ +-------------------+  |
|                                                  |               |              |
|                                                  v               v              |
|                                      +---------------------------------------+  |
|                                      |            RFBClientEngine            |  |
|                                      |      (RFBCore Standalone Package)     |  |
|                                      +---------------------------------------+  |
|                                                          |                      |
|                                                          v                      |
|                                      +---------------------------------------+  |
|                                      |           RFBNetworkSession           |  |
|                                      |       (Asynchronous TCP Stream)       |  |
|                                      +---------------------------------------+  |
|                                                          |                      |
+----------------------------------------------------------|----------------------+
                                                           | TCP (Port 5900)
                                                           v
                                            +------------------------------+
                                            |   Raspberry Pi / RFB Server  |
                                            +------------------------------+
```

---

## 4. Module Separation

### 4.1. `RFBCore` (UIKit-Free Standalone Swift Package)
- Pure protocol logic: `RFBVersion`, `RFBSecurity`, `RFBDES`, `RFBPixelFormat`, `RFBMessages`, `RFBConnectionState`, `RFBClientEngine`.
- Verifiable via `swift test` on macOS runners without any iOS simulator dependencies.
- Enforces strict memory caps: maximum desktop dimension = 4096, maximum rectangle count per update = 2048, maximum framebuffer memory allocation = 32 MB (tuned for 1 GB iPad RAM limit).

### 4.2. `Networking` (`RFBNetworkSession`)
- Asynchronous TCP socket streaming using `CFStream` / `Stream` scheduled on a dedicated background dispatch queue.
- Connection timeouts, partial reads, chunked writes, and complete cleanup on network loss.

### 4.3. `Rendering` (`FramebufferView`)
- Low-latency CoreGraphics bitmap rendering with `CGDataProvider` and `CGImage`.
- Dirty-rectangle invalidation (`setNeedsDisplay(rect)`).
- Accurate coordinate mapping from view space to remote framebuffer pixels.

### 4.4. `Input` (`InputHandler` & `KeyboardManager`)
- Tap -> left click, Pan -> left drag, Long-press -> right click, Two-finger pan -> mouse wheel scroll.
- Virtual hidden `UIKeyInput` field plus on-screen auxiliary key bar for modifier keys (Ctrl, Alt, Shift), navigation keys (Esc, Tab, Arrows), and desktop shortcuts (Ctrl+Alt+T, Ctrl+C, Ctrl+V).

### 4.5. `Security` (`KeychainManager`)
- Passwords stored exclusively in the iOS Keychain (`kSecClassGenericPassword`), never in `UserDefaults`, logs, or source code.
