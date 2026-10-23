# LegacyDisplay Comprehensive Test Plan

---

## 1. Test Levels & Strategy

LegacyDisplay employs a tiered test plan combining standalone unit tests, synthetic protocol tests, local mock server integration, and CI execution on Apple Silicon macOS runners.

| Tier | Environment | Target | Execution Method |
| :--- | :--- | :--- | :--- |
| **Tier 1: Protocol Core** | macOS / Linux / iOS | `RFBCore` | `swift test --package-path RFBCore` |
| **Tier 2: UI & Storage** | macOS / iOS Simulator | `LegacyDisplayTests` | `xcodebuild test` |
| **Tier 3: Mock Server** | Local Windows / Python | `tools/mock_rfb_server.py` | Local execution + `tools/rfb_probe.py` |
| **Tier 4: Live Probe** | LAN / Raspberry Pi | Physical RealVNC Server | `python tools/rfb_probe.py --host <IP>` |
| **Tier 5: Physical Device** | iPad Air (iOS 12.5.8) | Full Application | Sideloaded IPA verification |

---

## 2. Automated Test Matrix

### `RFBCore` Test Suite
- `testStandardVersionParsing`: Validates RFB 3.3, 3.7, 3.8 strings and byte sequences.
- `testRealVNCVersionParsing`: Validates handling of RealVNC `RFB 005.000` greetings.
- `testVersionNegotiation`: Confirms client negotiates RFB 3.8 when server offers 3.8 or 5.0.
- `testStandardVNCAuthSelected`: Verifies selection of Type 2 (VNC Auth).
- `testRealVNCProprietaryTypesTriggersPreciseDiagnosticMessage`: Ensures diagnostic alert when only Types [13, 5] are present.
- `testByteBitReversal`: Tests RFC 6143 bit-reversal algorithm against test vectors.
- `testDESBlockEncryptionKnownVector`: Verifies FIPS 46-3 DES encryption against standard vector (`0123456789ABCDEF` -> `85E813540F0AB405`).
- `testServerInitRejectsOversizedDimensions`: Protects 1 GB iPad RAM by enforcing 4096-pixel caps.
- `testRectangleBoundsValidation`: Confirms rejection of out-of-bounds rectangles.

### `LegacyDisplayTests` Suite
- `testConnectionProfileValidation`: Validates host non-empty and port 1..65535 constraints.
- `testConnectionViewControllerInstantiation`: Confirms clean UIKit view initialization on iOS 12.
- `testFramebufferCoordinateTransformation`: Validates view-to-desktop coordinate mapping under aspect fit.
- `testKeyboardManagerModifiers`: Tests toggle state machine for Ctrl, Alt, and Shift.
- `testKeychainManagerStorageCycle`: Verifies save, retrieve, and delete operations via iOS Keychain.
