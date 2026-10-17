import Foundation
import SwiftData

/// What Siri and the Shortcuts app get back from Ownwise (E3).
///
/// The intents themselves are deliberately trivial wrappers: everything that decides *what the answer
/// says* lives here, takes its container as a parameter, and is unit-tested. That also keeps the
/// intents free of stored state, which is what the App Intents metadata builder wants to see.
@MainActor
enum IntentAnswers {

    /// A spoken or shortcut answer, plus the data behind it.
    struct Answer: Sendable, Equatable {
        var count: Int
        var names: [String]
        var spoken: String
    }

    /// "What's expiring?" — the Home screen's Needs Attention, in words.
    static func needsAttention(in container: ModelContainer, now: Date = .now, maxNames: Int = 3) -> Answer {
        let items = (try? container.mainContext.fetch(FetchDescriptor<Item>())) ?? []
        let flagged = LibraryInsights.needsAttention(in: items, now: now)
        let names = flagged.prefix(max(maxNames, 0)).map(\.name)
        return Answer(count: flagged.count, names: names,
                      spoken: attentionSentence(count: flagged.count, names: names))
    }

    /// Spelled out per case rather than by concatenating a suffix, so it says "1 item needs
    /// attention" and never "1 items" (the same mistake G2 fixed in the reminder text).
    private static func attentionSentence(count: Int, names: [String]) -> String {
        switch count {
        case 0:
            return String(localized: "Nothing needs attention right now.", comment: "Siri answer")
        case 1:
            let name = names.first ?? String(localized: "One item", comment: "Siri answer fallback")
            return String(localized: "\(name) needs attention.", comment: "Siri answer, one item")
        default:
            let list = names.joined(separator: ", ")
            return String(localized: "\(count) items need attention: \(list).",
                          comment: "Siri answer, e.g. '3 items need attention: Kettle, TV.'")
        }
    }

    /// What happened when Siri was asked to add something.
    struct AddOutcome: Sendable, Equatable {
        var added: Bool
        var name: String
        var spoken: String
    }

    /// Adds an item from Shortcuts or Siri input.
    ///
    /// The free limit applies here too, or asking Siri would be a way around it, and a blank name
    /// creates nothing.
    static func addItem(named name: String,
                        purchaseDate: Date?,
                        price: Double?,
                        currencyCode: String?,
                        isPro: Bool,
                        in container: ModelContainer) -> AddOutcome {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AddOutcome(added: false, name: "",
                              spoken: String(localized: "I need a name before I can add an item.",
                                             comment: "Siri answer, empty name"))
        }

        let count = (try? container.mainContext.fetchCount(FetchDescriptor<Item>())) ?? 0
        guard isPro || count < StoreManager.freeItemLimit else {
            return AddOutcome(added: false, name: trimmed,
                              spoken: String(localized: "\(trimmed) was not added. Ownwise keeps \(StoreManager.freeItemLimit) items for free; Ownwise Pro removes the limit.",
                                             comment: "Siri answer when the free item limit is reached"))
        }

        let item = Item(name: trimmed)
        item.purchaseDate = purchaseDate ?? .now
        if let price, price >= 0 {
            // `Item` already defaults the currency from the locale; only override when told to.
            if let code = currencyCode, !code.isEmpty {
                item.currencyCode = code.uppercased()
            }
            item.priceMinor = Money.minorUnits(price, currencyCode: item.currencyCode)
        }
        container.mainContext.insert(item)
        container.mainContext.saveOrReport()

        return AddOutcome(added: true, name: trimmed,
                          spoken: String(localized: "Added \(trimmed) to Ownwise.", comment: "Siri answer after adding"))
    }
}
