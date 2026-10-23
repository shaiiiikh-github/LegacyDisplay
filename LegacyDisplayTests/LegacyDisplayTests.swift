import XCTest
@testable import LegacyDisplay

final class LegacyDisplayTests: XCTestCase {

    func testConnectionProfileValidation() {
        let validProfile = ConnectionProfile(name: "Pi Desk", host: "192.168.1.50", port: 5900)
        let (isValid, errorMsg) = validProfile.validate()
        XCTAssertTrue(isValid)
        XCTAssertNil(errorMsg)

        let emptyHostProfile = ConnectionProfile(name: "Pi Desk", host: "", port: 5900)
        let (emptyValid, emptyError) = emptyHostProfile.validate()
        XCTAssertFalse(emptyValid)
        XCTAssertNotNil(emptyError)

        let invalidPortProfile = ConnectionProfile(name: "Pi Desk", host: "192.168.1.50", port: 70000)
        let (portValid, portError) = invalidPortProfile.validate()
        XCTAssertFalse(portValid)
        XCTAssertNotNil(portError)
    }

    func testConnectionViewControllerInstantiation() {
        let vc = ConnectionViewController()
        vc.loadViewIfNeeded()
        XCTAssertNotNil(vc.view)
        XCTAssertEqual(vc.portTextField.text, "5900")
        XCTAssertEqual(vc.connectButton.title(for: .normal), "Connect to Desktop")
    }

    func testFramebufferCoordinateTransformation() {
        let fbView = FramebufferView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        fbView.updateDesktopDimensions(width: 1024, height: 768)

        // Point at center of view (512, 384) should map to center of framebuffer (512, 384)
        let mappedPoint = fbView.convertPointToFramebuffer(CGPoint(x: 512, y: 384))
        XCTAssertNotNil(mappedPoint)
        XCTAssertEqual(mappedPoint?.x ?? 0, 512, accuracy: 2.0)
        XCTAssertEqual(mappedPoint?.y ?? 0, 384, accuracy: 2.0)
    }

    func testKeyboardManagerModifiers() {
        let km = KeyboardManager()
        XCTAssertFalse(km.isCtrlActive)
        XCTAssertTrue(km.toggleCtrl())
        XCTAssertTrue(km.isCtrlActive)
        XCTAssertFalse(km.toggleCtrl())
        XCTAssertFalse(km.isCtrlActive)

        XCTAssertFalse(km.isAltActive)
        XCTAssertTrue(km.toggleAlt())
        XCTAssertTrue(km.isAltActive)
        km.releaseAllModifiers()
        XCTAssertFalse(km.isAltActive)
    }

    func testKeychainManagerStorageCycle() {
        let testHost = "127.0.0.1"
        let testPort = 5999
        let testPassword = "secureTestPassword"

        let saved = KeychainManager.shared.savePassword(testPassword, forHost: testHost, port: testPort)
        XCTAssertTrue(saved)

        let retrieved = KeychainManager.shared.getPassword(forHost: testHost, port: testPort)
        XCTAssertEqual(retrieved, testPassword)

        let deleted = KeychainManager.shared.deletePassword(forHost: testHost, port: testPort)
        XCTAssertTrue(deleted)

        let postDelete = KeychainManager.shared.getPassword(forHost: testHost, port: testPort)
        XCTAssertNil(postDelete)
    }
}
