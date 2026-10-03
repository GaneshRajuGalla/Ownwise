import Foundation
import LocalAuthentication
import Observation

@Observable
@MainActor
final class AppLock {
    var isLocked: Bool = false
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "appLockEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "appLockEnabled") }
    }
    private var backgroundedAt: Date?

    init() {
        if isEnabled && !LaunchEnvironment.isUITesting { isLocked = true }
    }

    func unlock() async {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Ownwise")
            if ok { isLocked = false }
        } catch { /* stay locked */ }
    }

    func didEnterBackground() { backgroundedAt = .now }
    func didBecomeActive() {
        guard isEnabled, !LaunchEnvironment.isUITesting else { return }
        if let bg = backgroundedAt, Date.now.timeIntervalSince(bg) > 60 { isLocked = true }
        backgroundedAt = nil
    }
}
