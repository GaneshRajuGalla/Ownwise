import AppIntents
import Foundation
import SwiftData

/// Siri and Shortcuts support (E3).
///
/// Two things anyone actually asks a warranty app: *what is about to run out*, and *note this
/// purchase*. Both are thin wrappers over `IntentAnswers`, so the wording and the rules stay in one
/// testable place.
///
/// The intents carry no stored state of their own (what the App Intents metadata builder expects), and
/// `perform()` is `@MainActor` because the store and the answer rules are — an `async` requirement may
/// be satisfied by an actor-isolated witness, so the system hops for us.
///
/// `supportedModes` is declared instead of the deprecated `openAppWhenRun`: neither intent needs the
/// app on screen, and the deployment target is iOS 26.

/// "What's expiring in Ownwise?" — reads the library, changes nothing.
struct ExpiringSoonIntent: AppIntent {
    static var title: LocalizedStringResource { "What's expiring" }
    static var description: IntentDescription {
        IntentDescription("Lists the items whose cover is running out, or that are due for service.")
    }
    static var supportedModes: IntentModes { .background }
    /// Only ever reads items the user already has in their own library.
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = IntentAnswers.needsAttention(in: Persistence.sharedContainer)
        return .result(dialog: "\(answer.spoken)")
    }
}

/// "Add an item to Ownwise" — the free limit applies exactly as it does in the app.
struct AddItemIntent: AppIntent {
    static var title: LocalizedStringResource { "Add an item" }
    static var description: IntentDescription {
        IntentDescription("Adds an item to the library, so its cover can be tracked.")
    }
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Name")
    var name: String

    @Parameter(title: "Bought on")
    var purchaseDate: Date?

    @Parameter(title: "Price")
    var price: Double?

    @Parameter(title: "Currency")
    var currencyCode: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let isPro = await StoreEntitlement.isPro()
        let outcome = IntentAnswers.addItem(named: name,
                                            purchaseDate: purchaseDate,
                                            price: price,
                                            currencyCode: currencyCode,
                                            isPro: isPro,
                                            in: Persistence.sharedContainer)
        return .result(dialog: "\(outcome.spoken)")
    }
}

/// What Siri offers before anyone has set anything up.
///
/// Every phrase has to contain `\(.applicationName)` — that is the system's rule, not a style choice.
struct OwnwiseShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ExpiringSoonIntent(),
                    phrases: ["What is expiring in \(.applicationName)",
                              "What needs attention in \(.applicationName)"],
                    shortTitle: "What's expiring",
                    systemImageName: "clock.badge.exclamationmark")
        AppShortcut(intent: AddItemIntent(),
                    phrases: ["Add an item to \(.applicationName)"],
                    shortTitle: "Add an item",
                    systemImageName: "plus.circle")
    }
}
