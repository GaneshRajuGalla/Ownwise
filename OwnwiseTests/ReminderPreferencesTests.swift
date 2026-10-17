import Testing
import Foundation
import SwiftData
@testable import Ownwise

@MainActor
struct ReminderPreferencesTests {

    @Test("Free defaults: returns 3/1, warranties 30/7/1, service on the day, 9:00")
    func defaults() {
        let p = ReminderPreferences.standard
        #expect(p.leads(for: .returnWindow) == [3, 1])
        #expect(p.leads(for: .manufacturer) == [30, 7, 1])
        #expect(p.leads(for: .insurance) == [30, 7, 1])
        #expect(p.leads(for: .servicePlan) == [0])
        #expect(p.hour == 9 && p.minute == 0)
    }

    @Test("Saved preferences round-trip through UserDefaults")
    func roundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReminderPreferencesTests"))
        defaults.removePersistentDomain(forName: "ReminderPreferencesTests")
        #expect(ReminderPreferences.load(from: defaults) == .standard)

        var custom = ReminderPreferences.standard
        custom.hour = 18; custom.minute = 30
        custom.returnLeads = [7, 0]
        custom.warrantyLeads = [90, 14]
        custom.save(to: defaults)
        #expect(ReminderPreferences.load(from: defaults) == custom)
        #expect(custom.leads(for: .extended) == [90, 14])
    }

    @Test("Fire date uses the preferred time on the given day")
    func fireDate() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .gmt
        var p = ReminderPreferences.standard
        p.hour = 18; p.minute = 30
        let day = cal.date(from: DateComponents(year: 2026, month: 5, day: 4, hour: 2))!
        #expect(cal.dateComponents([.year, .month, .day, .hour, .minute], from: p.fireDate(on: day, calendar: cal))
                == DateComponents(year: 2026, month: 5, day: 4, hour: 18, minute: 30))
    }

    @Test("Lead phrases read naturally", arguments: [
        ([30, 7, 1], "30, 7, and 1 days before"),
        ([1], "1 day before"),
        ([3, 0], "3 days before and on the day"),
        ([0], "on the day"),
        ([Int](), "Off"),
    ])
    func phrases(leads: [Int], expected: String) {
        // List formatting is locale-dependent; expectations are US English.
        guard Locale.current.identifier.hasPrefix("en_US") else { return }
        #expect(ReminderPreferences.leadsPhrase(leads) == expected)
    }

    @Test("Custom day counts: any whole number from 0 to 365", arguments: [
        ("45", 45), ("0", 0), ("365", 365), (" 21 ", 21),
        ("366", nil), ("-1", nil), ("abc", nil), ("", nil), ("2.5", nil),
    ] as [(String, Int?)])
    func validLead(text: String, expected: Int?) {
        #expect(ReminderPreferences.validLead(text) == expected)
    }

    @Test("Custom day counts are honored and sorted longest first")
    func customLeadsSorted() {
        var p = ReminderPreferences.standard
        p.warrantyLeads = [1, 45, 30]
        #expect(p.leads(for: .manufacturer) == [45, 30, 1])
    }

    @Test("Bulk apply reaches every coverage of that kind, and nothing else")
    func applyToEveryCoverageOfTheKind() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let edited = Coverage(kind: .manufacturer, start: .now, end: .now)
        let sameKindHere = Coverage(kind: .manufacturer, start: .now, end: .now)
        let otherKind = Coverage(kind: .returnWindow, start: .now, end: .now)
        let editedItem = Item(name: "Laptop")
        editedItem.coverages = [edited, sameKindHere, otherKind]
        let olderItem = Item(name: "TV")
        olderItem.coverages = [Coverage(kind: .manufacturer, start: .now, end: .now)]
        context.insert(editedItem)
        context.insert(olderItem)
        context.saveOrReport()

        let changed = ReminderPreferences.apply([1, 30], toKind: .manufacturer, except: edited, in: context)

        #expect(changed == 2, "the other warranty here plus the one on the older item")
        #expect(edited.reminderLeadDays == [30, 1], "the edited coverage too, sorted longest first")
        #expect(sameKindHere.reminderLeadDays == [30, 1])
        #expect((olderItem.coverages ?? []).first?.reminderLeadDays == [30, 1])
        #expect(otherKind.reminderLeadDays == nil, "a return window keeps its own timing")
    }
}
