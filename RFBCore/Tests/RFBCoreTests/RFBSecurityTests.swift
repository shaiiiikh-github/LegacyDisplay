import XCTest
@testable import RFBCore

final class RFBSecurityTests: XCTestCase {

    func testStandardVNCAuthSelected() {
        let result = RFBSecurityHandler.selectSecurityType(from: [1, 2, 16])
        XCTAssertEqual(result, .selected(.vncAuth))
    }

    func testNoneAuthSelectedWhenOnlyNoneAvailable() {
        let result = RFBSecurityHandler.selectSecurityType(from: [1])
        XCTAssertEqual(result, .selected(.none))
    }

    func testRealVNCProprietaryTypesTriggersPreciseDiagnosticMessage() {
        // Types 13 and 5 are what was discovered on the Raspberry Pi probe
        let result = RFBSecurityHandler.selectSecurityType(from: [13, 5])
        
        switch result {
        case .unsupportedSecurityMode(let types, let msg):
            XCTAssertEqual(types, [13, 5])
            XCTAssertTrue(msg.contains("RealVNC proprietary authentication"))
            XCTAssertTrue(msg.contains("VNC password"))
        default:
            XCTFail("Expected unsupportedSecurityMode for [13, 5]")
        }
    }

    func testEmptySecurityTypesFails() {
        let result = RFBSecurityHandler.selectSecurityType(from: [])
        switch result {
        case .connectionFailed:
            break
        default:
            XCTFail("Expected connectionFailed for empty types")
        }
    }
}
