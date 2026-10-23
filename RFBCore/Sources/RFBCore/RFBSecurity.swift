import Foundation

/// Standard and proprietary RFB security types.
public enum RFBSecurityType: UInt8, CaseIterable, CustomStringConvertible {
    case invalid = 0
    case none = 1
    case vncAuth = 2
    case ra2 = 5
    case ra2ne = 6
    case realVNC13 = 13
    case tight = 16
    case ultra = 17
    case tls = 18
    case veNCrypt = 19
    case gtkVncSasl = 20
    case md5 = 21
    case realVNC35 = 35

    public var description: String {
        switch self {
        case .invalid: return "Invalid / Connection Failed"
        case .none: return "None (No Authentication)"
        case .vncAuth: return "VNC Authentication (DES Challenge-Response)"
        case .ra2: return "RealVNC RA2 (RSA-AES)"
        case .ra2ne: return "RealVNC RA2ne"
        case .realVNC13: return "RealVNC Proprietary (Type 13)"
        case .tight: return "Tight"
        case .ultra: return "Ultra"
        case .tls: return "TLS"
        case .veNCrypt: return "VeNCrypt"
        case .gtkVncSasl: return "GTK-VNC SASL"
        case .md5: return "MD5"
        case .realVNC35: return "RealVNC System Authentication"
        }
    }

    /// Indicates whether this security type is supported natively by the client.
    public var isSupported: Bool {
        switch self {
        case .none, .vncAuth:
            return true
        default:
            return false
        }
    }
}

/// Result of evaluating security types advertised by the RFB server.
public enum RFBSecurityNegotiationResult: Equatable {
    case selected(RFBSecurityType)
    case connectionFailed(reason: String)
    case unsupportedSecurityMode(advertisedTypes: [UInt8], diagnosticMessage: String)
}

public struct RFBSecurityHandler {
    /// Evaluates advertised security types and chooses the preferred supported authentication mode.
    public static func selectSecurityType(from rawTypes: [UInt8]) -> RFBSecurityNegotiationResult {
        guard !rawTypes.isEmpty else {
            return .connectionFailed(reason: "Server sent empty security types list")
        }

        // Check if standard VNC Auth (2) is available (preferred over None if available)
        if rawTypes.contains(RFBSecurityType.vncAuth.rawValue) {
            return .selected(.vncAuth)
        }

        // Check if None (1) is available
        if rawTypes.contains(RFBSecurityType.none.rawValue) {
            return .selected(.none)
        }

        // None of the supported security types are present.
        // Check if RealVNC proprietary types are present (e.g. 5, 13, 35)
        let hasRealVNCProprietary = rawTypes.contains(5) || rawTypes.contains(13) || rawTypes.contains(35)
        let typeListStr = rawTypes.map { String($0) }.joined(separator: ", ")

        let message: String
        if hasRealVNCProprietary {
            message = "Server requires RealVNC proprietary authentication (advertised types: [\(typeListStr)]). " +
                      "Please configure RealVNC Server > Options > Security > Authentication to 'VNC password'."
        } else {
            message = "Server does not offer supported security types (advertised types: [\(typeListStr)]). " +
                      "Supported types: VNC Authentication (2) and None (1)."
        }

        return .unsupportedSecurityMode(advertisedTypes: rawTypes, diagnosticMessage: message)
    }
}
