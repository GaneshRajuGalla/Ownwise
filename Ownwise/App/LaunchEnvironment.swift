import Foundation

/// Launch-argument environment used by UI tests and previews.
/// `-uiTesting` (in-memory store, skip lock, auto-allow notifications)
/// `-seedSampleData`, `-resetOnboarding`, `-fixtureReceipt <name>`,
/// `-forcePro` / `-forceFree`.
enum LaunchEnvironment {
    static var args: [String] { ProcessInfo.processInfo.arguments }

    static var isUITesting: Bool { args.contains("-uiTesting") }
    static var seedSampleData: Bool { args.contains("-seedSampleData") }
    static var resetOnboarding: Bool { args.contains("-resetOnboarding") }
    static var forcePro: Bool { args.contains("-forcePro") }
    static var forceFree: Bool { args.contains("-forceFree") }

    static var fixtureReceipt: String? {
        guard let i = args.firstIndex(of: "-fixtureReceipt"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var skipOnboarding: Bool { args.contains("-skipOnboarding") }
}
