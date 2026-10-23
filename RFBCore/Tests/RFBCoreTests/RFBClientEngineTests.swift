import XCTest
@testable import RFBCore

final class MockEngineDelegate: RFBClientEngineDelegate {
    var sentPackets: [Data] = []
    var states: [RFBConnectionState] = []
    var updatedRects: [(x: UInt16, y: UInt16, width: UInt16, height: UInt16)] = []
    var desktopSizeChanges: [(width: UInt16, height: UInt16)] = []
    var encounteredErrors: [RFBConnectionError] = []

    func rfbEngine(_ engine: RFBClientEngine, didChangeState state: RFBConnectionState) {
        states.append(state)
    }

    func rfbEngine(_ engine: RFBClientEngine, didReceiveServerInit serverInit: RFBServerInit) {}

    func rfbEngine(_ engine: RFBClientEngine, didUpdateFramebufferRect x: UInt16, y: UInt16, width: UInt16, height: UInt16) {
        updatedRects.append((x, y, width, height))
    }

    func rfbEngine(_ engine: RFBClientEngine, didChangeDesktopSize width: UInt16, height: UInt16) {
        desktopSizeChanges.append((width, height))
    }

    func rfbEngine(_ engine: RFBClientEngine, didEncounterError error: RFBConnectionError) {
        encounteredErrors.append(error)
    }

    func rfbEngine(_ engine: RFBClientEngine, sendData data: Data) {
        sentPackets.append(data)
    }
}

final class RFBClientEngineTests: XCTestCase {

    func testFullHandshakeAndInitialUpdate() {
        let engine = RFBClientEngine(password: "secret", sharedDesktop: true)
        let delegate = MockEngineDelegate()
        engine.delegate = delegate

        // 1. Start connecting
        engine.startConnecting(host: "127.0.0.1", port: 5900)
        XCTAssertEqual(engine.state, .negotiatingVersion)

        // 2. Server sends version: RFB 003.008\n
        let serverVersionData = "RFB 003.008\n".data(using: .ascii)!
        engine.processIncomingData(serverVersionData)

        // Verify client negotiated version and sent client version back
        XCTAssertEqual(delegate.sentPackets.count, 1)
        XCTAssertEqual(delegate.sentPackets[0], "RFB 003.008\n".data(using: .ascii))

        // 3. Server sends security types: count=1, type=2 (VNC Authentication)
        engine.processIncomingData(Data([1, 2]))
        XCTAssertEqual(delegate.sentPackets.count, 2)
        XCTAssertEqual(delegate.sentPackets[1], Data([2])) // Chose Type 2

        // 4. Server sends 16-byte challenge
        let challenge = Data(repeating: 0x42, count: 16)
        engine.processIncomingData(challenge)
        XCTAssertEqual(delegate.sentPackets.count, 3)
        XCTAssertEqual(delegate.sentPackets[2].count, 16) // 16-byte encrypted response

        // 5. Server sends SecurityResult: 0 (OK)
        let okData = Data([0, 0, 0, 0])
        engine.processIncomingData(okData)
        XCTAssertEqual(delegate.sentPackets.count, 4)
        XCTAssertEqual(delegate.sentPackets[3], Data([1])) // ClientInit (shared=1)

        // 6. Server sends ServerInit: 800x600, 32-bit BGRA, name "Raspberry Pi"
        var serverInitData = Data()
        let width: UInt16 = 800
        let height: UInt16 = 600
        serverInitData.append(contentsOf: [UInt8(width >> 8), UInt8(width & 0xFF)])
        serverInitData.append(contentsOf: [UInt8(height >> 8), UInt8(height & 0xFF)])
        // Pixel format: bpp=32, depth=24, bigEndian=0, trueColor=1, rMax=255, gMax=255, bMax=255, rShift=16, gShift=8, bShift=0, pad=3
        let pfBytes: [UInt8] = [32, 24, 0, 1, 0, 255, 0, 255, 0, 255, 16, 8, 0, 0, 0, 0]
        serverInitData.append(contentsOf: pfBytes)
        let nameBytes = Array("Raspberry Pi".utf8)
        let nameLen = UInt32(nameBytes.count)
        serverInitData.append(contentsOf: [
            UInt8((nameLen >> 24) & 0xFF),
            UInt8((nameLen >> 16) & 0xFF),
            UInt8((nameLen >> 8) & 0xFF),
            UInt8(nameLen & 0xFF)
        ])
        serverInitData.append(contentsOf: nameBytes)

        engine.processIncomingData(serverInitData)

        // Verify connected state & desktop dimensions
        XCTAssertTrue(engine.state.isConnected)
        if case .connected(let w, let h, let name) = engine.state {
            XCTAssertEqual(w, 800)
            XCTAssertEqual(h, 600)
            XCTAssertEqual(name, "Raspberry Pi")
        } else {
            XCTFail("Expected .connected state")
        }
        XCTAssertEqual(engine.desktopWidth, 800)
        XCTAssertEqual(engine.desktopHeight, 600)
        XCTAssertEqual(engine.framebuffer.count, 800 * 600 * 4)

        // Verify client sent: SetPixelFormat (msg 0), SetEncodings (msg 2), FramebufferUpdateRequest (msg 3)
        XCTAssertTrue(delegate.sentPackets.count >= 7)

        // 7. Server sends FramebufferUpdate with 1 Raw rectangle (x=0, y=0, w=2, h=2)
        var fbUpdateData = Data()
        // Header: msgType=0, pad=0, rectCount=1
        fbUpdateData.append(contentsOf: [0, 0, 0, 1])
        // Rect: x=0, y=0, w=2, h=2, enc=0 (Raw)
        fbUpdateData.append(contentsOf: [0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 0])
        // Pixel data: 2x2 = 4 pixels, 4 bytes each = 16 bytes (Blue: 0xFF, 0x00, 0x00, 0xFF)
        let bluePixel: [UInt8] = [0xFF, 0x00, 0x00, 0xFF]
        for _ in 0..<4 {
            fbUpdateData.append(contentsOf: bluePixel)
        }

        engine.processIncomingData(fbUpdateData)

        // Verify delegate received dirty rect update
        XCTAssertEqual(delegate.updatedRects.count, 1)
        XCTAssertEqual(delegate.updatedRects[0].x, 0)
        XCTAssertEqual(delegate.updatedRects[0].y, 0)
        XCTAssertEqual(delegate.updatedRects[0].width, 2)
        XCTAssertEqual(delegate.updatedRects[0].height, 2)
    }

    func testUnsupportedSecurityTypeHandling() {
        let engine = RFBClientEngine()
        let delegate = MockEngineDelegate()
        engine.delegate = delegate

        engine.startConnecting(host: "172.21.238.234", port: 5900)
        engine.processIncomingData("RFB 003.008\n".data(using: .ascii)!)

        // Server advertises RealVNC proprietary Security Types [13, 5]
        engine.processIncomingData(Data([2, 13, 5]))

        // Verify engine transitions to failed with unsupportedSecurityMode
        XCTAssertEqual(delegate.encounteredErrors.count, 1)
        if case .unsupportedSecurityMode(let types, _) = delegate.encounteredErrors[0] {
            XCTAssertEqual(types, [13, 5])
        } else {
            XCTFail("Expected unsupportedSecurityMode error")
        }
    }

    func testPointerAndKeyEventSending() {
        let engine = RFBClientEngine()
        let delegate = MockEngineDelegate()
        engine.delegate = delegate

        // Send Pointer event
        engine.sendPointerEvent(buttonMask: 1, x: 100, y: 200)
        XCTAssertEqual(delegate.sentPackets.count, 1)
        let ptrData = delegate.sentPackets[0]
        XCTAssertEqual(ptrData[0], 5) // PointerEvent message type
        XCTAssertEqual(ptrData[1], 1) // Button mask (left click)

        // Send Key event
        engine.sendKeyEvent(down: true, keySym: 0xFF0D) // Return/Enter keysym
        XCTAssertEqual(delegate.sentPackets.count, 2)
        let keyData = delegate.sentPackets[1]
        XCTAssertEqual(keyData[0], 4) // KeyEvent message type
        XCTAssertEqual(keyData[1], 1) // Down flag
    }
}
