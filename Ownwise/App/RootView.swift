import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppLock.self) private var appLock
    @Environment(StoreManager.self) private var store
    @Environment(ReminderScheduler.self) private var reminder
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView { hasCompletedOnboarding = true }
            } else if appLock.isLocked {
                LockScreen()
            } else {
                AppTabs()
            }
        }
        // Pro unlocks custom reminder days/time and one-off reminders; reschedule whenever it changes.
        .task(id: store.isPro) {
            reminder.configure(isPro: store.isPro)
            await reminder.rescheduleFromContext(modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appLock.didEnterBackground()
            case .active: appLock.didBecomeActive()
            default: break
            }
        }
    }
}
