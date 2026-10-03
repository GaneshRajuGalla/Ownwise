import SwiftUI

struct RootView: View {
    @Environment(AppLock.self) private var appLock
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: appLock.didEnterBackground()
            case .active: appLock.didBecomeActive()
            default: break
            }
        }
        .overlay {
            if scenePhase != .active {
                Color.indigo.opacity(0.9).ignoresSafeArea()
            }
        }
    }
}
