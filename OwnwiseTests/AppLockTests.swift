import Testing
import Foundation
@testable import Ownwise

/// I4: the app lock's rules that can be exercised without Face ID.
@MainActor
struct AppLockTests {

    private static let enabledKey = "appLockEnabled"

    @Test("Turning the lock off always works and is remembered")
    func turningOff() async {
        defer { UserDefaults.standard.removeObject(forKey: Self.enabledKey) }
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        let lock = AppLock()

        let ok = await lock.setEnabled(false)

        #expect(ok)
        #expect(lock.isEnabled == false)
        #expect(lock.isLocked == false)
        #expect(UserDefaults.standard.bool(forKey: Self.enabledKey) == false,
                "the choice survives a relaunch")
    }

    @Test("A quick trip to the app switcher does not demand authentication again")
    func gracePeriod() {
        defer { UserDefaults.standard.removeObject(forKey: Self.enabledKey) }
        UserDefaults.standard.set(true, forKey: Self.enabledKey)
        let lock = AppLock()
        #expect(lock.isEnabled)

        var clock = Date(timeIntervalSince1970: 1_000_000)
        lock.now = { clock }
        lock.isLocked = false

        lock.didEnterBackground()
        clock = clock.addingTimeInterval(AppLock.gracePeriod - 5)
        lock.didBecomeActive()
        #expect(lock.isLocked == false, "coming straight back must not re-lock")

        lock.didEnterBackground()
        clock = clock.addingTimeInterval(AppLock.gracePeriod + 5)
        lock.didBecomeActive()
        #expect(lock.isLocked == true, "coming back much later does re-lock")
    }
}
