import Foundation

/// Opt-in iCloud sync (SwiftData + CloudKit).
///
/// Sync is deliberately gated on the build actually carrying the CloudKit entitlement, which is
/// advertised through the `OwnwiseICloudContainer` Info.plist key. Until that key is set, Ownwise
/// is local-only, the Settings row stays hidden, and the app never promises something its App ID
/// has not been granted. `docs/iCloud-sync.md` has the three steps that turn it on.
enum SyncSettings {
    private static let enabledKey = "iCloudSyncEnabled"

    /// The CloudKit container this build may sync with, if it has one.
    static var containerIdentifier: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "OwnwiseICloudContainer") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// True when this build has somewhere to sync to.
    static var isAvailable: Bool { containerIdentifier != nil }

    /// What the user chose. Always false while sync is unavailable, so the setting cannot lie.
    static var isEnabled: Bool {
        get { isAvailable && UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}
