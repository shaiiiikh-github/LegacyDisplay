import XCTest
@testable import RFBCore

final class RFBMessagesTests: XCTestCase {

    func testPixelFormatSerializationAndParsing() {
        let original = RFBPixelFormat.standard32
        let wire = original.wireData
        XCTAssertEqual(wire.count, 16)

        let parsed = RFBPixelFormat.parse(from: wire)
        XCTAssertEqual(parsed, original)
        XCTAssertEqual(parsed?.bitsPerPixel, 32)
        XCTAssertEqual(parsed?.depth, 24)
        XCTAssertEqual(parsed?.redMax, 255)
    }

    func testServerInitParsing() {
        var data = Data()
        // Width: 1024 (0x0400)
        data.append(contentsOf: [0x04, 0x00])
        // Height: 768 (0x0300)
        data.append(contentsOf: [0x03, 0x00])
        // PixelFormat (16 bytes)
        data.append(RFBPixelFormat.standard32.wireData)
        // Name length: 7 (0x00000007)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x07])
        // Name: "Pi-Desk"
        data.append(contentsOf: "Pi-Desk".utf8)

        let serverInit = RFBServerInit.parse(from: data)
        XCTAssertNotNil(serverInit)
        XCTAssertEqual(serverInit?.framebufferWidth, 1024)
        XCTAssertEqual(serverInit?.framebufferHeight, 768)
        XCTAssertEqual(serverInit?.name, "Pi-Desk")
    }

    func testServerInitRejectsOversizedDimensions() {
        var data = Data()
        // Width: 5000 (exceeds maxAllowedDimension of 4096)
        data.append(contentsOf: [0x13, 0x88])
        data.append(contentsOf: [0x03, 0x00])
        data.append(RFBPixelFormat.standard32.wireData)
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x04])
        data.append(contentsOf: "Test".utf8)

        let serverInit = RFBServerInit.parse(from: data)
        XCTAssertNil(serverInit, "Should reject dimensions exceeding memory safety caps")
    }

    func testRectangleBoundsValidation() {
        // Normal rect within 1024x768
        let validRect = RFBRectangleHeader(x: 100, y: 100, width: 200, height: 200, encodingType: 0)
        XCTAssertTrue(validRect.isWithinBounds(desktopWidth: 1024, desktopHeight: 768))

        // Rect exceeding desktop width (x + width = 1050 > 1024)
        let invalidRectX = RFBRectangleHeader(x: 900, y: 100, width: 150, height: 100, encodingType: 0)
        XCTAssertFalse(invalidRectX.isWithinBounds(desktopWidth: 1024, desktopHeight: 768))

        // Rect exceeding desktop height (y + height = 800 > 768)
        let invalidRectY = RFBRectangleHeader(x: 100, y: 700, width: 100, height: 100, encodingType: 0)
        XCTAssertFalse(invalidRectY.isWithinBounds(desktopWidth: 1024, desktopHeight: 768))
    }

    func testClientEventsSerialization() {
        let keyEvent = RFBClientMessage.keyEvent(down: true, keySym: 0xFF0D) // Enter
        XCTAssertEqual(keyEvent.count, 8)
        XCTAssertEqual(keyEvent[0], 4)
        XCTAssertEqual(keyEvent[1], 1)

        let pointerEvent = RFBClientMessage.pointerEvent(buttonMask: 1, x: 250, y: 350)
        XCTAssertEqual(pointerEvent.count, 6)
        XCTAssertEqual(pointerEvent[0], 5)
        XCTAssertEqual(pointerEvent[1], 1)
        XCTAssertEqual(pointerEvent[2], 0)
        XCTAssertEqual(pointerEvent[3], 250)
        XCTAssertEqual(pointerEvent[4], 1)
        XCTAssertEqual(pointerEvent[5], 94) // 350 = 256 + 94
    }
}
