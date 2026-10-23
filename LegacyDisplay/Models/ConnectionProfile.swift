import Foundation

/// Saved connection profile representation.
public struct ConnectionProfile: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var sharedDesktop: Bool

    public init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 5900,
        sharedDesktop: Bool = true
    ) {
        self.id = id
        self.name = name.isEmpty ? host : name
        self.host = host
        self.port = port
        self.sharedDesktop = sharedDesktop
    }

    /// Validates host and port bounds.
    public func validate() -> (isValid: Bool, errorMessage: String?) {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHost.isEmpty {
            return (false, "Host/IP address cannot be empty.")
        }
        if port < 1 || port > 65535 {
            return (false, "Port must be between 1 and 65535 (standard is 5900).")
        }
        return (true, nil)
    }
}

/// Storage manager for connection profiles.
public final class ProfileStorage {
    private static let storageKey = "LegacyDisplay_ConnectionProfiles"

    public static func loadProfiles() -> [ConnectionProfile] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profiles = try? JSONDecoder().decode([ConnectionProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    public static func saveProfiles(_ profiles: [ConnectionProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    public static func saveProfile(_ profile: ConnectionProfile) {
        var profiles = loadProfiles()
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        saveProfiles(profiles)
    }

    public static func deleteProfile(id: UUID) {
        var profiles = loadProfiles()
        profiles.removeAll(where: { $0.id == id })
        saveProfiles(profiles)
    }
}
