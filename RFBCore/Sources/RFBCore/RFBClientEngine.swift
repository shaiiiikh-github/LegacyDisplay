import Foundation

/// Delegate protocol for RFB client session events.
public protocol RFBClientEngineDelegate: AnyObject {
    func rfbEngine(_ engine: RFBClientEngine, didChangeState state: RFBConnectionState)
    func rfbEngine(_ engine: RFBClientEngine, didReceiveServerInit serverInit: RFBServerInit)
    func rfbEngine(_ engine: RFBClientEngine, didUpdateFramebufferRect x: UInt16, y: UInt16, width: UInt16, height: UInt16)
    func rfbEngine(_ engine: RFBClientEngine, didChangeDesktopSize width: UInt16, height: UInt16)
    func rfbEngine(_ engine: RFBClientEngine, didEncounterError error: RFBConnectionError)
    func rfbEngine(_ engine: RFBClientEngine, sendData data: Data)
}

/// The core RFB protocol processing engine.
/// Operates off the main thread; manages protocol handshakes, rectangle decoding, and framebuffer storage.
public final class RFBClientEngine {

    public private(set) var state: RFBConnectionState = .disconnected {
        didSet {
            delegate?.rfbEngine(self, didChangeState: state)
        }
    }

    public weak var delegate: RFBClientEngineDelegate?

    public private(set) var negotiatedVersion: RFBVersion?
    public private(set) var selectedSecurityType: RFBSecurityType?
    public private(set) var serverInit: RFBServerInit?

    // Framebuffer storage (32-bit BGRA: 4 bytes per pixel)
    public private(set) var desktopWidth: Int = 0
    public private(set) var desktopHeight: Int = 0
    public private(set) var framebuffer: [UInt8] = []

    // State machine tracking
    private var readBuffer = Data()
    private let password: String
    private var sharedDesktop: Bool = true
    private var expectingAuthResult = false
    private var currentExpectedRectangles: Int = 0

    public init(password: String = "", sharedDesktop: Bool = true) {
        self.password = password
        self.sharedDesktop = sharedDesktop
    }

    public func startConnecting(host: String, port: Int) {
        readBuffer.removeAll(keepingCapacity: true)
        state = .connecting(host: host, port: port)
        state = .negotiatingVersion
    }

    /// Feeds incoming network data into the RFB engine.
    public func processIncomingData(_ data: Data) {
        readBuffer.append(data)
        processReadBuffer()
    }

    private func processReadBuffer() {
        var progress = true
        while progress && !readBuffer.isEmpty {
            progress = processCurrentState()
        }
    }

    private func processCurrentState() -> Bool {
        switch state {
        case .negotiatingVersion:
            return processVersionNegotiation()
        case .negotiatingSecurity:
            return processSecurityNegotiation()
        case .authenticating:
            return processAuthentication()
        case .initializing:
            return processServerInit()
        case .connected:
            return processServerMessage()
        default:
            return false
        }
    }

    // MARK: - Handshake Processing

    private func processVersionNegotiation() -> Bool {
        guard readBuffer.count >= 12 else { return false }
        let versionData = readBuffer.prefix(12)
        readBuffer.removeFirst(12)

        guard let sVer = RFBVersion.parse(from: versionData) else {
            let err = RFBConnectionError.invalidProtocolVersion(
                String(data: versionData, encoding: .ascii) ?? "Unknown"
            )
            transitionToError(err)
            return false
        }

        let cVer = RFBVersion.negotiate(serverVersion: sVer)
        self.negotiatedVersion = cVer
        delegate?.rfbEngine(self, sendData: cVer.wireData)

        state = .negotiatingSecurity(serverVersion: sVer)
        return true
    }

    private func processSecurityNegotiation() -> Bool {
        guard let version = negotiatedVersion else { return false }

        if version.major == 3 && version.minor >= 7 {
            // RFB 3.7 and 3.8: 1 byte count, followed by N security types
            guard !readBuffer.isEmpty else { return false }
            let count = Int(readBuffer[0])

            if count == 0 {
                // Connection failed: read uint32 reason length + reason string
                guard readBuffer.count >= 5 else { return false }
                let reasonLen = Int(readBuffer[1]) << 24 | Int(readBuffer[2]) << 16 | Int(readBuffer[3]) << 8 | Int(readBuffer[4])
                guard readBuffer.count >= 5 + reasonLen else { return false }
                let reasonData = readBuffer.subdata(in: 5..<(5 + reasonLen))
                readBuffer.removeFirst(5 + reasonLen)
                let reason = String(data: reasonData, encoding: .isoLatin1) ?? "Connection refused by server"
                transitionToError(.serverRejected(reason: reason))
                return true
            }

            guard readBuffer.count >= 1 + count else { return false }
            let secTypes = Array(readBuffer.subdata(in: 1..<(1 + count)))
            readBuffer.removeFirst(1 + count)

            let result = RFBSecurityHandler.selectSecurityType(from: secTypes)
            switch result {
            case .selected(let secType):
                self.selectedSecurityType = secType
                // Send selected security type (1 byte)
                delegate?.rfbEngine(self, sendData: Data([secType.rawValue]))

                if secType == .none {
                    if version.minor >= 8 {
                        // RFB 3.8 expects SecurityResult for None
                        expectingAuthResult = true
                        state = .authenticating(securityType: .none)
                    } else {
                        // RFB 3.7 proceeds directly to ClientInit
                        sendClientInit()
                    }
                } else if secType == .vncAuth {
                    state = .authenticating(securityType: .vncAuth)
                }
                return true

            case .unsupportedSecurityMode(let types, let msg):
                transitionToError(.unsupportedSecurityMode(advertisedTypes: types, details: msg))
                return false

            case .connectionFailed(let reason):
                transitionToError(.serverRejected(reason: reason))
                return false
            }
        } else {
            // RFB 3.3: 4-byte uint32 security type directly
            guard readBuffer.count >= 4 else { return false }
            let secTypeVal = UInt8(readBuffer[3]) // lower byte of uint32
            readBuffer.removeFirst(4)

            guard let secType = RFBSecurityType(rawValue: secTypeVal), secType.isSupported else {
                transitionToError(.unsupportedSecurityMode(
                    advertisedTypes: [secTypeVal],
                    details: "Server selected unsupported RFB 3.3 security type: \(secTypeVal)"
                ))
                return false
            }

            self.selectedSecurityType = secType
            if secType == .none {
                sendClientInit()
            } else if secType == .vncAuth {
                state = .authenticating(securityType: .vncAuth)
            }
            return true
        }
    }

    private func processAuthentication() -> Bool {
        guard let secType = selectedSecurityType else { return false }

        if secType == .none && expectingAuthResult {
            // Read 4-byte SecurityResult
            guard readBuffer.count >= 4 else { return false }
            let result = UInt32(readBuffer[0]) << 24 | UInt32(readBuffer[1]) << 16 | UInt32(readBuffer[2]) << 8 | UInt32(readBuffer[3])
            readBuffer.removeFirst(4)

            if result == 0 {
                expectingAuthResult = false
                sendClientInit()
                return true
            } else {
                return parseAuthFailureReason()
            }
        } else if secType == .vncAuth {
            if !expectingAuthResult {
                // Read 16-byte random challenge
                guard readBuffer.count >= 16 else { return false }
                let challenge = readBuffer.subdata(in: 0..<16)
                readBuffer.removeFirst(16)

                guard let response = RFBDES.computeVNCAuthResponse(challenge: challenge, password: password) else {
                    transitionToError(.authenticationFailed(reason: "Failed to compute DES challenge response"))
                    return false
                }

                delegate?.rfbEngine(self, sendData: response)
                expectingAuthResult = true
                return true
            } else {
                // Read 4-byte SecurityResult
                guard readBuffer.count >= 4 else { return false }
                let result = UInt32(readBuffer[0]) << 24 | UInt32(readBuffer[1]) << 16 | UInt32(readBuffer[2]) << 8 | UInt32(readBuffer[3])
                readBuffer.removeFirst(4)

                if result == 0 {
                    expectingAuthResult = false
                    sendClientInit()
                    return true
                } else {
                    return parseAuthFailureReason()
                }
            }
        }
        return false
    }

    private func parseAuthFailureReason() -> Bool {
        if readBuffer.count >= 4 {
            let reasonLen = Int(readBuffer[0]) << 24 | Int(readBuffer[1]) << 16 | Int(readBuffer[2]) << 8 | Int(readBuffer[3])
            if readBuffer.count >= 4 + reasonLen {
                let reasonData = readBuffer.subdata(in: 4..<(4 + reasonLen))
                readBuffer.removeFirst(4 + reasonLen)
                let reason = String(data: reasonData, encoding: .isoLatin1) ?? "Invalid credentials"
                transitionToError(.authenticationFailed(reason: reason))
                return true
            }
        }
        transitionToError(.authenticationFailed(reason: "Incorrect password or authentication rejected"))
        return true
    }

    private func sendClientInit() {
        state = .initializing(desktopName: nil)
        // ClientInit: 1 byte shared-flag (1 = shared, 0 = exclusive)
        let sharedByte: UInt8 = sharedDesktop ? 1 : 0
        delegate?.rfbEngine(self, sendData: Data([sharedByte]))
    }

    private func processServerInit() -> Bool {
        guard readBuffer.count >= 24 else { return false }
        guard let sInit = RFBServerInit.parse(from: readBuffer) else {
            // Wait for more data or check if length invalid
            return false
        }

        let totalLength = 24 + sInit.name.utf8.count
        guard readBuffer.count >= totalLength else { return false }
        readBuffer.removeFirst(totalLength)

        self.serverInit = sInit
        self.desktopWidth = Int(sInit.framebufferWidth)
        self.desktopHeight = Int(sInit.framebufferHeight)

        // Allocate memory-bounded 32-bit BGRA framebuffer
        let totalPixels = desktopWidth * desktopHeight
        let bytesNeeded = totalPixels * 4
        // Hard safety check: max 32 MB for 1 GB iPad RAM limit
        guard bytesNeeded <= 33_554_432 else {
            transitionToError(.memoryAllocationExceeded("Desktop dimensions require \(bytesNeeded) bytes"))
            return false
        }
        self.framebuffer = [UInt8](repeating: 0, count: bytesNeeded)

        delegate?.rfbEngine(self, didReceiveServerInit: sInit)

        // Configure client pixel format (request standard 32-bit true colour)
        let setPf = RFBClientMessage.setPixelFormat(.standard32)
        delegate?.rfbEngine(self, sendData: setPf)

        // Request supported encodings (Raw, CopyRect, DesktopSize)
        let encodings: [RFBEncodingType] = [.copyRect, .raw, .desktopSize]
        let setEnc = RFBClientMessage.setEncodings(encodings)
        delegate?.rfbEngine(self, sendData: setEnc)

        state = .connected(
            desktopWidth: sInit.framebufferWidth,
            desktopHeight: sInit.framebufferHeight,
            desktopName: sInit.name
        )

        // Request first full framebuffer update
        requestFullFramebufferUpdate()
        return true
    }

    // MARK: - Server Messages & Framebuffer Updates

    private func processServerMessage() -> Bool {
        if currentExpectedRectangles > 0 {
            return processRectangles()
        }

        guard !readBuffer.isEmpty else { return false }
        let msgType = readBuffer[0]

        switch msgType {
        case 0: // FramebufferUpdate
            guard readBuffer.count >= 4 else { return false }
            let rectCount = Int(readBuffer[2]) << 8 | Int(readBuffer[3])
            readBuffer.removeFirst(4)

            // Hard safety check on rectangle count
            guard rectCount <= 2048 else {
                transitionToError(.malformedServerResponse("Oversized rectangle count: \(rectCount)"))
                return false
            }

            self.currentExpectedRectangles = rectCount
            if rectCount > 0 {
                return processRectangles()
            }
            return true

        case 1: // SetColourMapEntries (ignored in true-colour mode)
            guard readBuffer.count >= 6 else { return false }
            let count = Int(readBuffer[4]) << 8 | Int(readBuffer[5])
            let totalNeeded = 6 + count * 6
            guard readBuffer.count >= totalNeeded else { return false }
            readBuffer.removeFirst(totalNeeded)
            return true

        case 2: // Bell
            readBuffer.removeFirst(1)
            return true

        case 3: // ServerCutText
            guard readBuffer.count >= 8 else { return false }
            let len = Int(readBuffer[4]) << 24 | Int(readBuffer[5]) << 16 | Int(readBuffer[6]) << 8 | Int(readBuffer[7])
            guard readBuffer.count >= 8 + len else { return false }
            readBuffer.removeFirst(8 + len)
            return true

        default:
            transitionToError(.malformedServerResponse("Unknown server message type: \(msgType)"))
            return false
        }
    }

    private func processRectangles() -> Bool {
        while currentExpectedRectangles > 0 {
            guard readBuffer.count >= RFBRectangleHeader.headerSize else { return false }
            guard let header = RFBRectangleHeader.parse(from: readBuffer) else { return false }

            // Validate rectangle bounds
            guard header.isWithinBounds(desktopWidth: UInt16(desktopWidth), desktopHeight: UInt16(desktopHeight)) else {
                transitionToError(.malformedServerResponse("Rectangle [\(header.x),\(header.y),\(header.width),\(header.height)] exceeds desktop"))
                return false
            }

            if header.encodingType == RFBEncodingType.desktopSize.rawValue {
                // DesktopSize pseudo-encoding
                readBuffer.removeFirst(RFBRectangleHeader.headerSize)
                handleDesktopResize(newWidth: header.width, newHeight: header.height)
                currentExpectedRectangles -= 1
                continue
            } else if header.encodingType == RFBEncodingType.raw.rawValue {
                // Raw encoding: header + (w * h * 4 bytes for standard 32-bit pixel format)
                let pixelBytes = Int(header.width) * Int(header.height) * 4
                let totalNeeded = RFBRectangleHeader.headerSize + pixelBytes
                guard readBuffer.count >= totalNeeded else { return false }

                let rawPixelData = readBuffer.subdata(in: RFBRectangleHeader.headerSize..<totalNeeded)
                readBuffer.removeFirst(totalNeeded)

                decodeRawRectangle(header: header, pixelData: rawPixelData)
                currentExpectedRectangles -= 1

            } else if header.encodingType == RFBEncodingType.copyRect.rawValue {
                // CopyRect encoding: header + 4 bytes (srcX uint16, srcY uint16)
                let totalNeeded = RFBRectangleHeader.headerSize + 4
                guard readBuffer.count >= totalNeeded else { return false }

                let srcX = UInt16(readBuffer[12]) << 8 | UInt16(readBuffer[13])
                let srcY = UInt16(readBuffer[14]) << 8 | UInt16(readBuffer[15])
                readBuffer.removeFirst(totalNeeded)

                decodeCopyRect(header: header, srcX: srcX, srcY: srcY)
                currentExpectedRectangles -= 1

            } else {
                // Unsupported encoding encountered
                transitionToError(.malformedServerResponse("Unsupported encoding received: \(header.encodingType)"))
                return false
            }
        }
        return true
    }

    private func decodeRawRectangle(header: RFBRectangleHeader, pixelData: Data) {
        let rx = Int(header.x)
        let ry = Int(header.y)
        let rw = Int(header.width)
        let rh = Int(header.height)

        pixelData.withUnsafeBytes { rawPtr in
            guard let src = rawPtr.bindMemory(to: UInt8.self).baseAddress else { return }
            for row in 0..<rh {
                let dstY = ry + row
                let dstOffset = (dstY * desktopWidth + rx) * 4
                let srcOffset = row * rw * 4
                
                guard dstOffset + rw * 4 <= framebuffer.count else { continue }
                framebuffer.withUnsafeMutableBufferPointer { fbPtr in
                    guard let dst = fbPtr.baseAddress else { return }
                    memcpy(dst.advanced(by: dstOffset), src.advanced(by: srcOffset), rw * 4)
                }
            }
        }

        delegate?.rfbEngine(self, didUpdateFramebufferRect: header.x, y: header.y, width: header.width, height: header.height)
    }

    private func decodeCopyRect(header: RFBRectangleHeader, srcX: UInt16, srcY: UInt16) {
        let dx = Int(header.x)
        let dy = Int(header.y)
        let sx = Int(srcX)
        let sy = Int(srcY)
        let w = Int(header.width)
        let h = Int(header.height)

        let rowBytes = w * 4
        var tempBuffer = [UInt8](repeating: 0, count: rowBytes)

        // Determine vertical copy direction to avoid self-overwrite
        let yRange: [Int] = (dy < sy) ? Array(0..<h) : Array((0..<h).reversed())

        for row in yRange {
            let srcOffset = ((sy + row) * desktopWidth + sx) * 4
            let dstOffset = ((dy + row) * desktopWidth + dx) * 4
            
            guard srcOffset + rowBytes <= framebuffer.count,
                  dstOffset + rowBytes <= framebuffer.count else { continue }

            framebuffer.withUnsafeMutableBufferPointer { fbPtr in
                guard let base = fbPtr.baseAddress else { return }
                memcpy(&tempBuffer, base.advanced(by: srcOffset), rowBytes)
                memcpy(base.advanced(by: dstOffset), tempBuffer, rowBytes)
            }
        }

        delegate?.rfbEngine(self, didUpdateFramebufferRect: header.x, y: header.y, width: header.width, height: header.height)
    }

    private func handleDesktopResize(newWidth: UInt16, newHeight: UInt16) {
        self.desktopWidth = Int(newWidth)
        self.desktopHeight = Int(newHeight)
        let bytesNeeded = desktopWidth * desktopHeight * 4
        self.framebuffer = [UInt8](repeating: 0, count: bytesNeeded)
        delegate?.rfbEngine(self, didChangeDesktopSize: newWidth, height: newHeight)
        requestFullFramebufferUpdate()
    }

    // MARK: - Client Commands

    public func requestFullFramebufferUpdate() {
        let req = RFBClientMessage.framebufferUpdateRequest(
            incremental: false,
            x: 0,
            y: 0,
            width: UInt16(desktopWidth),
            height: UInt16(desktopHeight)
        )
        delegate?.rfbEngine(self, sendData: req)
    }

    public func requestIncrementalUpdate() {
        let req = RFBClientMessage.framebufferUpdateRequest(
            incremental: true,
            x: 0,
            y: 0,
            width: UInt16(desktopWidth),
            height: UInt16(desktopHeight)
        )
        delegate?.rfbEngine(self, sendData: req)
    }

    public func sendPointerEvent(buttonMask: UInt8, x: UInt16, y: UInt16) {
        let event = RFBClientMessage.pointerEvent(buttonMask: buttonMask, x: x, y: y)
        delegate?.rfbEngine(self, sendData: event)
    }

    public func sendKeyEvent(down: Bool, keySym: UInt32) {
        let event = RFBClientMessage.keyEvent(down: down, keySym: keySym)
        delegate?.rfbEngine(self, sendData: event)
    }

    public func disconnect() {
        state = .disconnected
        readBuffer.removeAll()
    }

    private func transitionToError(_ error: RFBConnectionError) {
        state = .failed(error: error)
        delegate?.rfbEngine(self, didEncounterError: error)
    }
}
