import Testing
import Foundation
import SwiftData
@testable import Ownwise

/// What Siri and Shortcuts are told, and what they are allowed to do (E3).
@MainActor
struct IntentAnswersTests {

    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func date(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: now)!
    }

    private func container() -> ModelContainer {
        Persistence.makeContainer(inMemory: true)
    }

    @Test("Nothing, one, or several — said in words, with no \"1 items\"")
    func wording() throws {
        let container = container()
        let context = container.mainContext

        let nothing = IntentAnswers.needsAttention(in: container, now: now)
        #expect(nothing.count == 0)
        #expect(nothing.spoken == "Nothing needs attention right now.")

        let kettle = Item(name: "Kettle")
        kettle.coverages = [Coverage(kind: .manufacturer, start: date(-300), end: date(10))]
        context.insert(kettle)
        context.saveOrReport()

        let one = IntentAnswers.needsAttention(in: container, now: now)
        #expect(one.count == 1)
        #expect(one.names == ["Kettle"])
        #expect(one.spoken == "Kettle needs attention.")
        #expect(!one.spoken.contains("1 items"))

        let tv = Item(name: "TV")
        tv.coverages = [Coverage(kind: .manufacturer, start: date(-300), end: date(20))]
        let washer = Item(name: "Washer")
        let service = CoverageBuilder.make(kind: .servicePlan, start: date(-250), length: 6)
        washer.coverages = [service]
        context.insert(tv)
        context.insert(washer)
        context.saveOrReport()

        let several = IntentAnswers.needsAttention(in: container, now: now)
        #expect(several.count == 3)
        #expect(Set(several.names) == ["Kettle", "TV", "Washer"])
        #expect(several.spoken.hasPrefix("3 items need attention: "))
        for name in several.names {
            #expect(several.spoken.contains(name))
        }

        // Asking for fewer names still reports the true count.
        let short = IntentAnswers.needsAttention(in: container, now: now, maxNames: 1)
        #expect(short.count == 3)
        #expect(short.names.count == 1)
    }

    @Test("Adding from Siri obeys the same free limit as the app")
    func addRespectsTheLimit() throws {
        let container = container()
        let context = container.mainContext
        for index in 0..<StoreManager.freeItemLimit {
            context.insert(Item(name: "Item \(index)"))
        }
        context.saveOrReport()

        let refused = IntentAnswers.addItem(named: "Kettle", purchaseDate: nil, price: nil,
                                            currencyCode: nil, isPro: false, in: container)
        #expect(refused.added == false)
        #expect(refused.spoken.contains("Kettle"))
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == StoreManager.freeItemLimit)

        let allowed = IntentAnswers.addItem(named: "Kettle", purchaseDate: nil, price: nil,
                                            currencyCode: nil, isPro: true, in: container)
        #expect(allowed.added)
        #expect(try context.fetchCount(FetchDescriptor<Item>()) == StoreManager.freeItemLimit + 1)
    }

    @Test("A blank name adds nothing at all")
    func blankName() throws {
        let container = container()

        let outcome = IntentAnswers.addItem(named: "   ", purchaseDate: nil, price: nil,
                                            currencyCode: nil, isPro: true, in: container)

        #expect(outcome.added == false)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Item>()) == 0)
    }

    @Test("What Siri was told is stored the way the app stores it")
    func fields() throws {
        let container = container()
        let bought = date(-40)

        let outcome = IntentAnswers.addItem(named: "  Kettle  ", purchaseDate: bought, price: 49.99,
                                            currencyCode: "eur", isPro: true, in: container)

        #expect(outcome.added)
        #expect(outcome.name == "Kettle")
        let item = try #require(try container.mainContext.fetch(FetchDescriptor<Item>()).first)
        #expect(item.name == "Kettle")
        #expect(item.purchaseDate == bought)
        #expect(item.currencyCode == "EUR", "the currency is normalised, as the review screen does")
        #expect(item.priceMinor == 4999)
    }

    @Test("No date means today, and no price means nothing was invented")
    func defaults() throws {
        let container = container()

        _ = IntentAnswers.addItem(named: "Kettle", purchaseDate: nil, price: nil,
                                  currencyCode: nil, isPro: true, in: container)

        let item = try #require(try container.mainContext.fetch(FetchDescriptor<Item>()).first)
        #expect(abs(item.purchaseDate.timeIntervalSinceNow) < 60)
        #expect(item.priceMinor == nil)
    }
}
