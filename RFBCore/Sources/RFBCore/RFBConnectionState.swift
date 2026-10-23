import Foundation

/// Explicit connection state machine for the RFB client (Section 3, Rule 7).
public enum RFBConnectionState: Equatable, CustomStringConvertible {
    case disconnected
    case connecting(host: String, port: Int)
    case negotiatingVersion
    case negotiatingSecurity(serverVersion: RFBVersion)
    case authenticating(securityType: RFBSecurityType)
    case initializing(desktopName: String?)
    case connected(desktopWidth: UInt16, desktopHeight: UInt16, desktopName: String)
    case reconnecting(attempt: Int, delaySeconds: Double)
    case failed(error: RFBConnectionError)

    public var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting(let host, let port):
            return "Connecting to \(host):\(port)..."
        case .negotiatingVersion:
            return "Negotiating Protocol Version..."
        case .negotiatingSecurity(let v):
            return "Negotiating Security (\(v))..."
        case .authenticating(let type):
            return "Authenticating (\(type.description))..."
        case .initializing(let name):
            return "Initializing Session (\(name ?? "Desktop"))..."
        case .connected(let w, let h, let name):
            return "Connected to \(name) (\(w)x\(h))"
        case .reconnecting(let attempt, _):
            return "Reconnecting (attempt \(attempt))..."
        case .failed(let err):
            return "Failed: \(err.localizedDescription)"
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var isConnecting: Bool {
        switch self {
        case .connecting, .negotiatingVersion, .negotiatingSecurity, .authenticating, .initializing, .reconnecting:
            return true
        default:
            return false
        }
    }
}

/// Structured RFB connection errors.
public enum RFBConnectionError: Equatable, LocalizedError {
    case invalidHostOrPort(String)
    case connectionTimedOut
    case networkError(String)
    case invalidProtocolVersion(String)
    case unsupportedSecurityMode(advertisedTypes: [UInt8], details: String)
    case authenticationFailed(reason: String)
    case serverRejected(reason: String)
    case malformedServerResponse(String)
    case memoryAllocationExceeded(String)
    case connectionCancelled
    case connectionClosedByServer

    public var errorDescription: String? {
        switch self {
        case .invalidHostOrPort(let msg):
            return "Invalid host or port: \(msg)"
        case .connectionTimedOut:
            return "Connection timed out. Check that the VNC server is running and the device is on the same local network."
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .invalidProtocolVersion(let v):
            return "Invalid server protocol version: \(v)"
        case .unsupportedSecurityMode(_, let details):
            return details
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason). Verify the password and server settings."
        case .serverRejected(let reason):
            return "Server rejected connection: \(reason)"
        case .malformedServerResponse(let msg):
            return "Protocol error: \(msg)"
        case .memoryAllocationExceeded(let msg):
            return "Memory safety limit reached: \(msg)"
        case .connectionCancelled:
            return "Connection cancelled by user."
        case .connectionClosedByServer:
            return "Connection closed by remote server."
        }
    }
}
