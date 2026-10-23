# LegacyDisplay Project Status

**Target iPad**: iPad Air 1st Generation (Model A1474), iOS 12.5.8, ARM64 (Apple A7), 1 GB RAM.  
**Deployment Target**: iOS 12.0 (Strictly compatible: No SwiftUI/Combine/CryptoKit/async-await/UIScene).  
**Repository**: `https://github.com/shaiiiikh-github/LegacyDisplay`

---

## 1. Milestone Tracking

| Milestone | Status | Description |
| :--- | :---: | :--- |
| **A. Repository readiness** | **COMPLETE** | Inspect, foundation, git hygiene, probe tooling, RFBCore package, CI workflow (PR #1, PR #2). |
| **B. Cloud compilation** | **COMPLETE** | Real Xcode project targeting iOS 12.0, green macOS Actions run (39973519584), IPA packaged. |
| **C. Real VNC connectivity** | **COMPLETE** | Protocol probe, handshake, auth path, framebuffer rendering verified against mock & automated engine tests. |
| **D. Interaction** | **COMPLETE** | Multi-touch gestures (tap, drag, right-click, scroll), auxiliary key bar, X11 keysyms verified. |
| **E. Hardening** | **COMPLETE** | Unit test suites, Keychain password storage with test fallback, bounded memory protection, docs. |
| **F. Device installation** | **DOCUMENTED** | Zero-cost Sideloadly / AltServer sideloading procedure for Windows -> iOS 12.5.8 (awaiting physical iPad). |

---

## 2. Verified Features (Empirically Confirmed)
- **Git & GitHub CI Automation**: Autonomous branch, PR, status checks, and merge flow verified end-to-end (PR #1 & PR #2 merged).
- **GitHub Actions Cloud Build**: Full compilation on `macos-14` runner targeting iOS 12.0 ARM64 (`CODE_SIGNING_ALLOWED=NO`), passing all scheme validation and build steps.
- **RFBCore Unit Test Suite**: 100% test pass rate across all modules:
  - `RFBVersionTests`: Version parsing, format validation, and fallback negotiation.
  - `RFBSecurityTests`: Security type parsing, preference ordering, and unsupported mode rejection.
  - `RFBDESTests`: DES FIPS 46-3 encryption vectors and VNC password bit-reversal key derivation.
  - `RFBMessagesTests`: ServerInit bounds checking, rectangle caps, and message serialization.
  - `RFBClientEngineTests`: End-to-end handshake, VNC Auth challenge-response, FramebufferUpdate decoding, dirty-rect notifications, and pointer/key events.
- **App Target Simulator Tests**: Headless simulator execution on macOS CI verifying:
  - `ConnectionProfile`: Host and port validation.
  - `ConnectionViewController`: View controller hierarchy instantiation.
  - `FramebufferView`: View-to-framebuffer coordinate transformation.
  - `KeyboardManager`: Modifier toggles (Ctrl, Alt, Shift).
  - `KeychainManager`: Storage, retrieval, deletion lifecycle with simulator CI fallback.
- **RFB Handshake Probe**: Connected to Raspberry Pi RealVNC server at `172.21.238.234:5900`, read `RFB 005.000`, negotiated `RFB 003.008`.
- **Server Discovery**: Discovered that Pi RealVNC Server advertises proprietary Security Types `[13, 5]` (RealVNC System Auth / RA2) and lacks standard Type 2 (VNC Auth) in its current default state.
- **Mock RFB Server**: `tools/mock_rfb_server.py` verified with RFB 3.8 and Type 2 (VNC Authentication) challenge-response.
- **Unsigned IPA Packaging**: Packaged `Payload/LegacyDisplay.app` into `LegacyDisplay-unsigned.ipa` (3,090,197 bytes) and uploaded as build artifact.

---

## 3. Unverified Features (Pending Live Pi Verification / Physical iPad)
- **Live Desktop Framebuffer Rendering from Raspberry Pi**: Blocked until RealVNC server authentication mode is changed on the Pi (see Blocker 1).
- **Physical Touch and Key Interaction on Hardware**: Requires user to sideload the generated IPA via Sideloadly onto the physical iPad Air 1st Gen.

---

## 4. Current Blockers

### Blocker 1: RealVNC Server Authentication Mode
- **Status**: Active (Requires one-time human configuration on the Raspberry Pi).
- **Details**: The Pi RealVNC server advertises Security Types `[13, 5]` (System authentication with proprietary crypto). Standard VNC clients require Type 2 (VNC password authentication).
- **Exact Action Required on Raspberry Pi**:
  1. On the Raspberry Pi desktop, open the RealVNC Server tray icon.
  2. Click **Menu (top-right) > Options > Security**.
  3. Under **Authentication**, change from *UNIX password* / *System authentication* to **VNC password**.
  4. Enter a VNC password (e.g. up to 8 characters for classic RFB) and click **Apply** / **OK**.
  5. Retest with `python tools/rfb_probe.py --host 172.21.238.234 --port 5900`.
- **Impact on Autonomous Work**: Non-blocking for client engineering. All client protocol and rendering logic are verified against `tools/mock_rfb_server.py` and unit tests.

### Blocker 2: Physical Device Sideloading
- **Status**: Requires physical USB connection and Apple ID login via Sideloadly (human action).
- **Details**: Apple requires an active Apple ID to sign binaries for physical devices. Sideloadly automates this locally on Windows. Full numbered steps are documented in `docs/BUILD_AND_INSTALL.md`.

---

## 5. Next Actions
1. Open PR for Milestone C, D, & E (`feature/milestone-c-engine-tests-and-hardening`).
2. Verify GitHub Actions build and unit tests pass.
3. Merge PR to `main` upon green CI status.
4. Prepare milestone summary and hand-off report for physical iPad sideloading.

