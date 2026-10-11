import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct OwnwiseApp: App {
    let container: ModelContainer

    @State private var storeManager: StoreManager
    @State private var appLock: AppLock
    @State private var reminder: ReminderScheduler

    init() {
        let c = Persistence.makeContainer(inMemory: LaunchEnvironment.isUITesting)
        container = c

        let force: Bool? = LaunchEnvironment.forcePro ? true : (LaunchEnvironment.forceFree ? false : nil)
        let s = StoreManager(forcePro: force)
        _storeManager = State(initialValue: s)
        _appLock = State(initialValue: AppLock())
        let r = ReminderScheduler()
        _reminder = State(initialValue: r)

        BGTaskScheduler.shared.register(forTaskWithIdentifier: ReminderScheduler.taskID, using: nil) { task in
            Task { @MainActor in
                let items = (try? c.mainContext.fetch(FetchDescriptor<Item>())) ?? []
                // Background launches may not render any view, so apply Pro preferences here too.
                await s.refreshEntitlements()
                r.configure(isPro: s.isPro)
                await r.rescheduleAll(items: items)
                task.setTaskCompleted(success: true)
                await Self.scheduleRefresh()
            }
        }

        if LaunchEnvironment.resetOnboarding {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        if LaunchEnvironment.skipOnboarding {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(storeManager)
                .environment(appLock)
                .environment(reminder)
                .task {
                    if LaunchEnvironment.seedSampleData {
                        let ctx = container.mainContext
                        if ((try? ctx.fetchCount(FetchDescriptor<Item>())) ?? 0) == 0 {
                            Persistence.seedSampleData(into: ctx)
                        }
                    }
                    await storeManager.start()
                    if LaunchEnvironment.isUITesting {
                        await reminder.grantPermissionForUITesting()
                    } else {
                        // The permission prompt itself is shown from onboarding, never over it.
                        await reminder.refreshAuthorizationStatus()
                        await Self.scheduleRefresh()
                    }
                }
        }
        .modelContainer(container)
    }

    static func scheduleRefresh() async {
        let request = BGAppRefreshTaskRequest(identifier: ReminderScheduler.taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600 * 12)
        try? BGTaskScheduler.shared.submit(request)
    }
}
