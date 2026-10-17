import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import Ownwise

@MainActor
struct ReminderPresetTests {

    // MARK: Presets

    @Test("Presets are curated per kind, longest lead first")
    func presets() {
        #expect(ReminderPreferences.presets(for: .returnWindow) == [14, 7, 3, 1, 0])
        #expect(ReminderPreferences.presets(for: .servicePlan) == [30, 7, 0])
        for kind in [CoverageKind.manufacturer, .extended, .insurance] {
            #expect(ReminderPreferences.presets(for: kind) == [90, 30, 14, 7, 1, 0])
        }
    }

    @Test("Every kind offers presets, and the ceiling can hold them all")
    func presetsFitTheCeiling() {
        for kind in CoverageKind.allCases {
            let options = ReminderPreferences.presets(for: kind)
            #expect(!options.isEmpty)
            #expect(!ReminderPreferences.defaultLeads(for: kind).isEmpty)
            // A chip the user taps must actually stick.
            #expect(options.count <= ReminderPreferences.maxLeads, "\(kind) has more presets than maxLeads")
            #expect(options.allSatisfy { $0 <= ReminderPreferences.maxLeadDays })
        }
    }

    @Test("Leads are sorted, de-duplicated, filtered and capped")
    func normalize() {
        #expect(ReminderPreferences.normalizedLeads([1, 30, 7, 30]) == [30, 7, 1])
        #expect(ReminderPreferences.normalizedLeads([-5, 0]) == [0])
        #expect(ReminderPreferences.normalizedLeads([400]) == [])
        #expect(ReminderPreferences.normalizedLeads(Array(1...20)).count == ReminderPreferences.maxLeads)
    }

    // MARK: Selection rules (kept out of the view on purpose)

    @Test("Toggling chips adds, removes, and falls back to the default")
    func toggling() {
        #expect(ReminderPreferences.toggling(7, in: [30, 7]) == [30])
        #expect(ReminderPreferences.toggling(14, in: [30, 7]) == [30, 14, 7])
        // Dropping the last chip means "back to the smart default", never "no reminders".
        #expect(ReminderPreferences.toggling(30, in: [30]) == nil)
        #expect(ReminderPreferences.toggling(14, in: [14]) == nil)
        // Duplicates in stored data don't desync the chips.
        #expect(ReminderPreferences.toggling(30, in: [30, 30, 7]) == [7])
    }

    @Test("Every preset can be selected in one pass")
    func everyPresetSelectable() {
        for kind in CoverageKind.allCases {
            let options = ReminderPreferences.presets(for: kind)
            var selection: [Int] = []
            for day in options { selection = ReminderPreferences.toggling(day, in: selection) ?? [] }
            #expect(Set(selection) == Set(options), "\(kind) dropped a preset: \(selection)")
        }
    }

    @Test("Custom day counts are added without duplicating or busting the ceiling")
    func addingCustom() {
        #expect(ReminderPreferences.adding(45, to: [30, 7]) == [45, 30, 7])
        #expect(ReminderPreferences.adding(30, to: [30, 7]) == [30, 7])
        let full = Array(1...ReminderPreferences.maxLeads)
        #expect(ReminderPreferences.adding(200, to: full) == ReminderPreferences.normalizedLeads(full))
    }

    @Test("Global settings can go fully off, and share the per-item ceiling")
    func globalSelection() {
        #expect(ReminderPreferences.togglingGlobal(1, in: [3, 1]) == [3])
        // "Off" is a valid global state, unlike for a single item.
        #expect(ReminderPreferences.togglingGlobal(3, in: [3]) == [])
        #expect(ReminderPreferences.togglingGlobal(30, in: [3, 3]) == [30, 3])
        let full = Array(1...ReminderPreferences.maxLeads)
        #expect(ReminderPreferences.togglingGlobal(90, in: full) == ReminderPreferences.normalizedLeads(full))
    }

    @Test("Global lists are normalized, so Settings can't overrun the ceiling")
    func globalIsNormalized() {
        var prefs = ReminderPreferences.standard
        prefs.warrantyLeads = [30, 30, -5, 400, 7, 1, 2, 3, 4, 5, 6, 8]
        let leads = prefs.leads(for: .manufacturer)
        #expect(leads == ReminderPreferences.normalizedLeads(prefs.warrantyLeads))
        #expect(leads.count == ReminderPreferences.maxLeads)
        #expect(leads.allSatisfy { (0...ReminderPreferences.maxLeadDays).contains($0) })
    }

    @Test("The chips an item shows lit are the reminders that actually fire")
    func chipsMatchSchedule() {
        var prefs = ReminderPreferences.standard
        prefs.warrantyLeads = [60, 14, 14, 3]        // a messy Pro global list
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: true, saved: prefs)

        let plain = manufacturer()
        let item = Item(name: "Oven")
        item.coverages = [plain]

        // What the item's picker shows as the smart default …
        let shown = prefs.leads(for: .manufacturer)
        #expect(scheduler.leads(for: plain) == shown)
        // … is exactly what gets scheduled.
        let ids = Set(scheduler.makeRequests(items: [item]).map(\.identifier))
        #expect(ids == Set(shown.map { ReminderScheduler.notificationID(coverageID: plain.id, lead: $0) }))
    }

    // MARK: Labels

    @Test("Chip labels use weeks and months where it helps")
    func chipLabels() {
        #expect(ReminderPreferences.chipLabel(0) == "On the day")
        #expect(ReminderPreferences.chipLabel(1) == "1 day before")
        #expect(ReminderPreferences.chipLabel(7) == "1 week before")
        #expect(ReminderPreferences.chipLabel(14) == "2 weeks before")
        #expect(ReminderPreferences.chipLabel(30) == "1 month before")
        #expect(ReminderPreferences.chipLabel(90) == "3 months before")
        #expect(ReminderPreferences.chipLabel(45) == "45 days before")
    }

    @Test("Phrases read naturally", arguments: [
        ([30, 7, 1], "1 month, 1 week, and 1 day before"),
        ([3, 1], "3 and 1 days before"),
        ([1], "1 day before"),
        ([30, 7, 1, 0], "1 month, 1 week, and 1 day before, plus on the day"),
        ([0], "on the day"),
        ([Int](), "Off"),
    ] as [([Int], String)])
    func phrases(leads: [Int], expected: String) {
        // List formatting is locale-dependent; expectations are US English.
        guard Locale.current.identifier.hasPrefix("en_US") else { return }
        #expect(ReminderPreferences.presetPhrase(leads) == expected)
    }

    // MARK: Scheduling precedence

    private func manufacturer(endInDays days: Int = 200) -> Coverage {
        Coverage(kind: .manufacturer, start: .now, end: Calendar.current.date(byAdding: .day, value: days, to: .now)!)
    }

    @Test("A per-coverage choice beats the global setting")
    func overrideBeatsGlobal() {
        let item = Item(name: "Fridge")
        let coverage = manufacturer()
        coverage.reminderLeadDays = [45]
        item.coverages = [coverage]

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: true, saved: .standard)
        #expect(scheduler.leads(for: coverage) == [45])
        #expect(Set(scheduler.makeRequests(items: [item]).map(\.identifier))
                == [ReminderScheduler.notificationID(coverageID: coverage.id, lead: 45)])
    }

    @Test("An unset or empty choice falls back to the smart default")
    func emptyFallsBack() {
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let unset = manufacturer()
        let emptied = manufacturer()
        emptied.reminderLeadDays = []
        #expect(scheduler.leads(for: unset) == [30, 7, 1])
        #expect(scheduler.leads(for: emptied) == [30, 7, 1])
    }

    @Test("A per-coverage choice applies to service plans too")
    func servicePlanHeadsUp() {
        let item = Item(name: "Washer")
        let coverage = Coverage(kind: .servicePlan, start: .now, end: .distantFuture)
        coverage.serviceIntervalMonths = 12
        coverage.lastServiceDate = .now
        coverage.reminderLeadDays = [30, 0]
        item.coverages = [coverage]

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let ids = Set(scheduler.makeRequests(items: [item]).map(\.identifier))
        #expect(ids == [ReminderScheduler.notificationID(coverageID: coverage.id, lead: 30),
                        ReminderScheduler.notificationID(coverageID: coverage.id, lead: 0)])
    }

    @Test("Service plans with no choice still remind on the due day only")
    func servicePlanDefault() {
        let item = Item(name: "Boiler")
        let coverage = Coverage(kind: .servicePlan, start: .now, end: .distantFuture)
        coverage.serviceIntervalMonths = 6
        coverage.lastServiceDate = .now
        item.coverages = [coverage]

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        #expect(scheduler.makeRequests(items: [item]).map(\.identifier)
                == [ReminderScheduler.notificationID(coverageID: coverage.id, lead: 0)])
    }

    // MARK: Date handling

    @Test("A reminder lands on the right local day at the preferred hour")
    func dateMath() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        // Far enough out to cross a daylight-saving change in the interval.
        let end = cal.date(byAdding: .month, value: 14, to: .now)!
        let targetDay = cal.date(byAdding: .day, value: -30, to: end)!

        let item = Item(name: "Laptop")
        let coverage = Coverage(kind: .manufacturer, start: end, end: end)
        coverage.reminderLeadDays = [30]
        item.coverages = [coverage]

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let comps = scheduler.makeRequests(items: [item], calendar: cal)
            .first.flatMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents }

        #expect(comps?.year == cal.component(.year, from: targetDay))
        #expect(comps?.month == cal.component(.month, from: targetDay))
        #expect(comps?.day == cal.component(.day, from: targetDay))
        #expect(comps?.hour == 9 && comps?.minute == 0)
        // The day/hour above are what matters: they are computed in the user's
        // calendar, and the trigger carries no fixed time zone (per README §7.5),
        // so it fires at that wall-clock time wherever the user is.
    }

    @Test("A lead whose date has already passed is never scheduled")
    func pastLeadSkipped() {
        let item = Item(name: "Kettle")
        let coverage = Coverage(kind: .returnWindow, start: .now,
                                end: Calendar.current.date(byAdding: .day, value: 30, to: .now)!)
        coverage.reminderLeadDays = [90]   // 3 months before a 30-day window: long gone
        item.coverages = [coverage]

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        #expect(scheduler.makeRequests(items: [item]).isEmpty)
    }

    @Test("Expired coverage schedules nothing")
    func expiredCoverage() {
        let item = Item(name: "Old phone")
        item.coverages = [Coverage(kind: .manufacturer, start: .now,
                                   end: Calendar.current.date(byAdding: .day, value: -5, to: .now)!)]
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        #expect(scheduler.makeRequests(items: [item]).isEmpty)
    }

    @Test("Duplicate leads collapse into one reminder")
    func duplicateLeadsCollapse() {
        // Apple replaces a pending request that reuses an identifier, so two
        // identical leads would silently fight over one notification.
        let item = Item(name: "TV")
        let coverage = manufacturer()
        coverage.reminderLeadDays = [7, 7, 7]
        item.coverages = [coverage]

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let requests = scheduler.makeRequests(items: [item])
        #expect(requests.count == 1)
        #expect(requests.map(\.identifier) == [ReminderScheduler.notificationID(coverageID: coverage.id, lead: 7)])
    }

    @Test("The 60-notification ceiling holds even with many per-item leads")
    func ceilingHoldsWithOverrides() {
        let item = Item(name: "Kitchen")
        item.coverages = (0..<20).map { offset in
            let coverage = Coverage(kind: .manufacturer, start: .now,
                                    end: Calendar.current.date(byAdding: .day, value: 60 + offset, to: .now)!)
            coverage.reminderLeadDays = [30, 14, 7, 1]   // 20 × 4 = 80 candidates
            return coverage
        }

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let requests = scheduler.makeRequests(items: [item])
        #expect(requests.count == ReminderScheduler.maxScheduled)
        let ids = requests.map(\.identifier)
        #expect(Set(ids).count == ids.count)
    }

    // MARK: Storage

    @Test("A chosen schedule survives a store round trip")
    func persistence() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = container.mainContext

        let item = Item(name: "Kettle")
        let chosen = manufacturer()
        chosen.reminderLeadDays = [45, 7]
        let untouched = manufacturer(endInDays: 100)
        item.coverages = [chosen, untouched]
        context.insert(item)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Coverage>())
        #expect(stored.count == 2)
        #expect(stored.first { $0.id == chosen.id }?.reminderLeadDays == [45, 7])
        // Untouched coverages stay nil, so the smart default keeps applying.
        #expect(stored.first { $0.id == untouched.id }?.reminderLeadDays == nil)
    }

    @Test("An existing v1 store migrates to v2 with the data intact")
    func migratesFromV1() throws {
        let directory = URL.temporaryDirectory.appending(path: "ownwise-v1-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Ownwise.store")

        // Write through the old schema, exactly as a shipped v1 app would have:
        // v1 knew nothing about a migration plan, so don't pass one here.
        do {
            let v1 = Schema(versionedSchema: SchemaV1.self)
            let old = try ModelContainer(for: v1,
                                         configurations: ModelConfiguration(schema: v1, url: storeURL))
            let context = old.mainContext
            let item = SchemaV1.Item(name: "Old TV")
            item.coverages = [SchemaV1.Coverage(kind: .manufacturer, start: .now, end: .now)]
            context.insert(item)
            try context.save()
        }

        // Reopen the same file on v2.
        let v2 = Schema(versionedSchema: SchemaV2.self)
        let migrated = try ModelContainer(for: v2, migrationPlan: MigrationPlan.self,
                                          configurations: ModelConfiguration(schema: v2, url: storeURL))
        let items = try migrated.mainContext.fetch(FetchDescriptor<Item>())
        #expect(items.count == 1)
        #expect(items.first?.name == "Old TV")
        #expect(items.first?.coverages?.count == 1)
        // The new attribute defaults to nil, so v1 behaviour is preserved.
        #expect(items.first?.coverages?.first?.reminderLeadDays == nil)
    }
}
