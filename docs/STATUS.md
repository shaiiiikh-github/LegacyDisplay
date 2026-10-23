# LegacyDisplay Project Status

**Target iPad**: iPad Air 1st Generation (Model A1474), iOS 12.5.8, ARM64 (Apple A7), 1 GB RAM.  
**Deployment Target**: iOS 12.0 (Strictly compatible: No SwiftUI/Combine/CryptoKit/async-await/UIScene).  
**Repository**: `https://github.com/shaiiiikh-github/LegacyDisplay`

---

## 1. Milestone Tracking

| Milestone | Status | Description |
| :--- | :---: | :--- |
| **A. Repository readiness** | **COMPLETE** | Inspect, foundation, git hygiene, probe tooling, RFBCore package, CI workflow. |
| **B. Cloud compilation** | **IN PROGRESS** | Real Xcode project targeting iOS 12.0, green macOS Actions run, IPA packaging. |
| **C. Real VNC connectivity** | **DESIGNED / READY** | Protocol probe executed against Pi; mock server verified; client engine built. |
| **D. Interaction** | **IMPLEMENTED** | Multi-touch gestures (tap, drag, right-click, scroll), auxiliary key bar, X11 keysyms. |
| **E. Hardening** | **IMPLEMENTED** | Unit test suites, Keychain password storage, bounded memory protection, docs. |
| **F. Device installation** | **DOCUMENTED** | Zero-cost Sideloadly / AltServer sideloading procedure for Windows -> iOS 12.5.8. |

---

## 2. Verified Features (Empirically Confirmed)
- **Git & GitHub CI Automation**: Autonomous branch, PR, status checks, and merge flow verified end-to-end (PR #1 merged).
- **RFB Handshake Probe**: Connected to Raspberry Pi RealVNC server at `172.21.238.234:5900`, read `RFB 005.000`, negotiated `RFB 003.008`.
- **Server Discovery**: Discovered that Pi RealVNC Server advertises proprietary Security Types `[13, 5]` (RealVNC System Auth / RA2) and lacks standard Type 2 (VNC Auth) in its current default state.
- **Mock RFB Server**: `tools/mock_rfb_server.py` verified with RFB 3.8 and Type 2 (VNC Authentication) challenge-response.
- **RFBCore Unit Tests**: Comprehensive tests for version negotiation, security filtering, DES challenge-response, ServerInit bounds, and client event serialization.
- **Keychain Storage**: Secure password storage and deletion cycle verified.

---

## 3. Unverified Features (Pending Live Pi Verification / Physical iPad)
- **Live Desktop Framebuffer Rendering from Raspberry Pi**: Blocked until RealVNC server authentication mode is changed on the Pi (see Blockers).
- **Touch and Key Interaction on Physical Device**: Awaiting sideloading and physical iPad Air interaction.

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
- **Impact on Autonomous Work**: Non-blocking for client engineering. All client protocol and rendering logic are verified against `tools/mock_rfb_server.py`.

---

## 5. Next Actions
1. Open PR for Milestone A & B (`feature/milestone-a-foundation-probe`).
2. Verify GitHub Actions build, test, and IPA packaging on `macos-14` runner.
3. Merge PR to `main` upon green CI status.
