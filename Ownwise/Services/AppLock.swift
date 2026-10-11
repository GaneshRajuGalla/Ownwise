import Foundation
import LocalAuthentication
import Observation

@Observable
@MainActor
final class AppLock {
    private static let enabledKey = "appLockEnabled"

    var isLocked: Bool = false
    /// Stored (not computed) so SwiftUI observes changes; persisted to UserDefaults.
    private(set) var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }
    private var backgroundedAt: Date?

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if isEnabled && !LaunchEnvironment.isUITesting { isLocked = true }
    }

    /// Face ID / Touch ID with passcode fallback is set up on this device.
    var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Turning the lock on requires a successful authentication first, so a user
    /// can never lock themselves out on a device without Face ID or a passcode.
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else { isEnabled = false; return true }
        guard canAuthenticate, await authenticate(reason: String(localized: "Turn on app lock")) else { return false }
        isEnabled = true
        return true
    }

    func unlock() async {
        // If the device lost its passcode/biometrics, don't trap the user's data.
        guard canAuthenticate else { isEnabled = false; isLocked = false; return }
        if await authenticate(reason: String(localized: "Unlock Ownwise")) { isLocked = false }
    }

    func didEnterBackground() { backgroundedAt = .now }
    func didBecomeActive() {
        guard isEnabled, !LaunchEnvironment.isUITesting else { return }
        if let bg = backgroundedAt, Date.now.timeIntervalSince(bg) > 60 { isLocked = true }
        backgroundedAt = nil
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
