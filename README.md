# LegacyDisplay

Native iPad VNC Client turning an iPad Air (1st Generation, iOS 12.5.8) into a dedicated wireless display and control surface for a Raspberry Pi desktop over a local network.

---

## Target Environment & Specifications
- **Device**: iPad Air (1st generation, Model A1474), ARM64 Apple A7, 1 GB RAM.
- **Operating System**: iOS 12.5.8.
- **Deployment Target**: iOS 12.0 (Strictly compatible: No SwiftUI, Combine, CryptoKit, async/await, or UIScene).
- **Architecture**: Landscape-first remote desktop display with multi-touch gestures, auxiliary keyboard bar, and secure Keychain storage.
- **Protocol**: RFB 3.8 (RFC 6143), VNC Authentication (Type 2 DES challenge-response), None (Type 1), Raw and CopyRect encodings.

---

## Project Structure
```
LegacyDisplay/
├── RFBCore/                          # UIKit-free standalone Swift Package (protocol core)
│   ├── Package.swift
│   ├── Sources/RFBCore/              # RFBVersion, RFBSecurity, RFBDES, RFBMessages, RFBClientEngine
│   └── Tests/RFBCoreTests/           # Unit tests (version, security, DES, message bounds)
├── LegacyDisplay.xcodeproj/          # Xcode Project (shared scheme, iOS 12.0 target)
├── LegacyDisplay/                    # iOS UIKit Application
│   ├── App/                          # AppDelegate (standard iOS 12 UIWindow lifecycle)
│   ├── Models/                       # ConnectionProfile, ProfileStorage
│   ├── Networking/                   # RFBNetworkSession (asynchronous TCP streaming)
│   ├── Rendering/                    # FramebufferView (CoreGraphics bitmap rendering)
│   ├── Input/                        # InputHandler (multi-touch), KeyboardManager (X11 keysyms)
│   ├── Security/                     # KeychainManager (iOS Keychain password storage)
│   ├── Views/                        # ConnectionViewController, RemoteDisplayViewController
│   ├── Resources/                    # Assets.xcassets, LaunchScreen.storyboard
│   └── Info.plist
├── LegacyDisplayTests/               # Application-level unit tests
├── tools/
│   ├── rfb_probe.py                  # RFB handshake probe tool
│   └── mock_rfb_server.py            # Local mock RFB 3.8 test server
├── docs/                             # Engineering documentation
│   ├── STATUS.md                     # Milestone tracking & verified features
│   ├── BLOCKERS.md                   # External blockers & exact resolutions
│   ├── ARCHITECTURE.md               # Technical architecture & probe findings
│   ├── TROUBLESHOOTING.md            # Raspberry Pi VNC setup instructions
│   ├── BUILD_AND_INSTALL.md          # Windows sideloading guide for iOS 12.5.8
│   ├── SECURITY.md                   # Security model & DES limitations
│   └── TEST_PLAN.md                  # Multi-tier testing matrix
└── .github/workflows/ios-build.yml   # GitHub Actions macOS-14 CI workflow
```

---

## Real Server Probe Findings
Connecting to the Raspberry Pi test server (`172.21.238.234:5900`) using `tools/rfb_probe.py` revealed:
- Server reports `RFB 005.000` (RealVNC proprietary server).
- Server advertises Security Types `[13, 5]` (UNIX system authentication with proprietary crypto).
- Standard RFC 6143 Type 2 (VNC Authentication) requires configuring **VNC password** authentication in RealVNC Server options (see [docs/TROUBLESHOOTING.md](file:///D:/Projects/LegacyDisplay/docs/TROUBLESHOOTING.md)).

---

## Build & Test Workflow

### Standalone Protocol Tests
Run `swift test` on any macOS or Linux machine:
```bash
swift test --package-path RFBCore
```

### GitHub Actions CI
Every commit and Pull Request triggers the automated pipeline on `macos-14`:
1. Xcode 15.4 / 16.0 activation.
2. `swift test --package-path RFBCore`.
3. Verifies deployment target is `12.0`.
4. Builds for generic iOS device with code signing disabled.
5. Runs application tests on an iOS Simulator.
6. Packages an unsigned IPA (`LegacyDisplay-unsigned.ipa`) and uploads it as an artifact.

### Sideloading onto iPad Air (iOS 12.5.8)
See [docs/BUILD_AND_INSTALL.md](file:///D:/Projects/LegacyDisplay/docs/BUILD_AND_INSTALL.md) for step-by-step instructions using Sideloadly and a free Apple ID from Windows over USB.
