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
        _storeManager = State(initialValue: StoreManager(forcePro: force))
        _appLock = State(initialValue: AppLock())
        let r = ReminderScheduler()
        _reminder = State(initialValue: r)

        BGTaskScheduler.shared.register(forTaskWithIdentifier: ReminderScheduler.taskID, using: nil) { task in
            Task { @MainActor in
                let items = (try? c.mainContext.fetch(FetchDescriptor<Item>())) ?? []
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
                    await storeManager.startListening()
                    if LaunchEnvironment.isUITesting {
                        await reminder.grantPermissionForUITesting()
                    } else {
                        await reminder.requestPermissionIfNeeded()
                    }
                }
        }
        .modelContainer(container)
    }

    static func scheduleRefresh() async {
        if #available(iOS 27, *) {
            let request = BGAppRefreshTaskRequest(identifier: ReminderScheduler.taskID)
            request.earliestBeginDate = Date(timeIntervalSinceNow: 3600 * 12)
            try? await BGTaskScheduler.shared.submitTaskRequest(request)
        }
    }
}
