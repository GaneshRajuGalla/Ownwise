import Foundation

/// The App Group this app shares with its extensions, if it has one.
///
/// One lookup, used by everything that crosses the app/extension boundary (E1's share inbox, E2's
/// widget snapshot), so they cannot disagree about where the shared folder is.
///
/// **Nothing is configured by default.** The container is named by the `OwnwiseAppGroupID` key in
/// Info.plist; with no key — or with the capability not yet granted — `containerURL` is nil and every
/// caller degrades to doing nothing, which is what keeps today's build exactly as it was. The steps
/// that turn it on are in `docs/share-extension.md`.
///
/// `nonisolated`: an extension or widget asks for it from wherever it happens to be running.
nonisolated enum AppGroup {
    static let infoKey = "OwnwiseAppGroupID"

    static var groupID: String? {
        Bundle.main.object(forInfoDictionaryKey: infoKey) as? String
    }

    /// The shared container's URL, or nil when there is no group configured or granted.
    static var containerURL: URL? {
        guard let groupID else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    /// A named folder inside the shared container. Nil when there is no container.
    static func directory(_ name: String) -> URL? {
        containerURL?.appending(path: name, directoryHint: .isDirectory)
    }
}
