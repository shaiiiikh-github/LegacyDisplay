import Foundation

/// Encodings supported or recognized in RFB protocol (RFC 6143).
public enum RFBEncodingType: Int32, CaseIterable {
    case raw = 0
    case copyRect = 1
    case rre = 2
    case hextile = 5
    case zrle = 16
    case cursor = -239
    case desktopSize = -223

    public var name: String {
        switch self {
        case .raw: return "Raw"
        case .copyRect: return "CopyRect"
        case .rre: return "RRE"
        case .hextile: return "Hextile"
        case .zrle: return "ZRLE"
        case .cursor: return "Cursor (Pseudo-Encoding)"
        case .desktopSize: return "DesktopSize (Pseudo-Encoding)"
        }
    }
}

/// ServerInit message received after authentication completes (RFC 6143 Section 7.3.2).
public struct RFBServerInit: Equatable {
    public let framebufferWidth: UInt16
    public let framebufferHeight: UInt16
    public let pixelFormat: RFBPixelFormat
    public let name: String

    /// Maximum allowable dimensions to prevent unbounded memory allocation (tuned for 1 GB RAM).
    public static let maxAllowedDimension: UInt16 = 4096
    public static let maxNameLength: UInt32 = 1024

    public init(framebufferWidth: UInt16, framebufferHeight: UInt16, pixelFormat: RFBPixelFormat, name: String) {
        self.framebufferWidth = framebufferWidth
        self.framebufferHeight = framebufferHeight
        self.pixelFormat = pixelFormat
        self.name = name
    }

    public static func parse(from data: Data) -> RFBServerInit? {
        // Minimum size: 2 + 2 + 16 + 4 = 24 bytes
        guard data.count >= 24 else { return nil }
        
        let width = UInt16(data[0]) << 8 | UInt16(data[1])
        let height = UInt16(data[2]) << 8 | UInt16(data[3])

        // Validate dimensions
        guard width > 0, width <= maxAllowedDimension,
              height > 0, height <= maxAllowedDimension else {
            return nil
        }

        guard let format = RFBPixelFormat.parse(from: data.subdata(in: 4..<20)) else {
            return nil
        }

        let nameLen = UInt32(data[20]) << 24 | UInt32(data[21]) << 16 | UInt32(data[22]) << 8 | UInt32(data[23])
        guard nameLen <= maxNameLength,
              data.count >= 24 + Int(nameLen) else {
            return nil
        }

        let nameData = data.subdata(in: 24..<(24 + Int(nameLen)))
        let name = String(data: nameData, encoding: .latin1) ?? "VNC Server"

        return RFBServerInit(
            framebufferWidth: width,
            framebufferHeight: height,
            pixelFormat: format,
            name: name
        )
    }
}

/// Client-to-server messages (RFC 6143 Section 7.5).
public struct RFBClientMessage {

    /// Type 0: SetPixelFormat
    public static func setPixelFormat(_ format: RFBPixelFormat) -> Data {
        var data = Data([0, 0, 0, 0]) // message-type = 0, 3 bytes padding
        data.append(format.wireData)
        return data
    }

    /// Type 2: SetEncodings
    public static func setEncodings(_ encodings: [RFBEncodingType]) -> Data {
        var data = Data([2, 0]) // message-type = 2, 1 byte padding
        var count = UInt16(encodings.count).bigEndian
        data.append(Data(bytes: &count, count: 2))
        for enc in encodings {
            var val = enc.rawValue.bigEndian
            data.append(Data(bytes: &val, count: 4))
        }
        return data
    }

    /// Type 3: FramebufferUpdateRequest
    public static func framebufferUpdateRequest(
        incremental: Bool,
        x: UInt16,
        y: UInt16,
        width: UInt16,
        height: UInt16
    ) -> Data {
        var data = Data([3, incremental ? 1 : 0])
        var xBig = x.bigEndian
        var yBig = y.bigEndian
        var wBig = width.bigEndian
        var hBig = height.bigEndian
        data.append(Data(bytes: &xBig, count: 2))
        data.append(Data(bytes: &yBig, count: 2))
        data.append(Data(bytes: &wBig, count: 2))
        data.append(Data(bytes: &hBig, count: 2))
        return data
    }

    /// Type 4: KeyEvent
    public static func keyEvent(down: Bool, keySym: UInt32) -> Data {
        var data = Data([4, down ? 1 : 0, 0, 0]) // type=4, down-flag, 2 bytes padding
        var sym = keySym.bigEndian
        data.append(Data(bytes: &sym, count: 4))
        return data
    }

    /// Type 5: PointerEvent
    public static func pointerEvent(buttonMask: UInt8, x: UInt16, y: UInt16) -> Data {
        var data = Data([5, buttonMask])
        var xBig = x.bigEndian
        var yBig = y.bigEndian
        data.append(Data(bytes: &xBig, count: 2))
        data.append(Data(bytes: &yBig, count: 2))
        return data
    }
}

/// Rectangle header in FramebufferUpdate (RFC 6143 Section 7.6.1).
public struct RFBRectangleHeader: Equatable {
    public let x: UInt16
    public let y: UInt16
    public let width: UInt16
    public let height: UInt16
    public let encodingType: Int32

    public static let headerSize = 12

    public static func parse(from data: Data) -> RFBRectangleHeader? {
        guard data.count >= headerSize else { return nil }
        let x = UInt16(data[0]) << 8 | UInt16(data[1])
        let y = UInt16(data[2]) << 8 | UInt16(data[3])
        let w = UInt16(data[4]) << 8 | UInt16(data[5])
        let h = UInt16(data[6]) << 8 | UInt16(data[7])
        let enc = Int32(data[8]) << 24 | Int32(data[9]) << 16 | Int32(data[10]) << 8 | Int32(data[11])

        return RFBRectangleHeader(x: x, y: y, width: w, height: h, encodingType: enc)
    }

    /// Validates rectangle bounds against the desktop dimensions to prevent buffer overflows.
    public func isWithinBounds(desktopWidth: UInt16, desktopHeight: UInt16) -> Bool {
        if encodingType == RFBEncodingType.desktopSize.rawValue {
            return true
        }
        return (UInt32(x) + UInt32(width) <= UInt32(desktopWidth)) &&
               (UInt32(y) + UInt32(height) <= UInt32(desktopHeight))
    }
}
