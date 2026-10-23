import Foundation

/// Represents the RFB protocol version.
public struct RFBVersion: Equatable, CustomStringConvertible {
    public let major: Int
    public let minor: Int

    public static let v3_3 = RFBVersion(major: 3, minor: 3)
    public static let v3_7 = RFBVersion(major: 3, minor: 7)
    public static let v3_8 = RFBVersion(major: 3, minor: 8)

    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    public var description: String {
        return String(format: "RFB %03d.%03d", major, minor)
    }

    /// Formats the 12-byte wire protocol version string (e.g. "RFB 003.008\n").
    public var wireData: Data {
        let string = String(format: "RFB %03d.%03d\n", major, minor)
        return Data(string.utf8)
    }

    /// Parses a 12-byte server version announcement.
    public static func parse(from data: Data) -> RFBVersion? {
        guard data.count >= 12,
              let string = String(data: data.prefix(12), encoding: .ascii) else {
            return nil
        }
        return parse(from: string)
    }

    /// Parses a string representation such as "RFB 003.008\n" or "RFB 005.000\n".
    public static func parse(from string: String) -> RFBVersion? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("RFB ") else { return nil }

        let versionPart = trimmed.dropFirst(4)
        let components = versionPart.split(separator: ".")
        guard components.count == 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            return nil
        }
        return RFBVersion(major: major, minor: minor)
    }

    /// Determines the standard client version to negotiate with a given server version.
    /// In RFB, if the server offers version >= 3.8 (including RealVNC 5.x/4.x), the standard client replies with 3.8.
    public static func negotiate(serverVersion: RFBVersion) -> RFBVersion {
        if serverVersion.major > 3 || (serverVersion.major == 3 && serverVersion.minor >= 8) {
            return .v3_8
        } else if serverVersion.major == 3 && serverVersion.minor == 7 {
            return .v3_7
        } else {
            return .v3_3
        }
    }
}
