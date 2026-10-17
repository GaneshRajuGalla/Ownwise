import Testing
import Foundation
import UserNotifications
@testable import Ownwise

@MainActor
struct ReminderSchedulerTests {

    @Test("Notification ID scheme")
    func idScheme() {
        let id = UUID()
        #expect(ReminderScheduler.notificationID(coverageID: id, lead: 3) == "cov-\(id.uuidString)-3")
    }

    @Test("Leads per kind")
    func leads() {
        #expect(ReminderScheduler.leads(for: .returnWindow) == [3, 1])
        #expect(ReminderScheduler.leads(for: .manufacturer) == [30, 7, 1])
        #expect(ReminderScheduler.leads(for: .extended) == [30, 7, 1])
        #expect(ReminderScheduler.leads(for: .insurance) == [30, 7, 1])
        #expect(ReminderScheduler.leads(for: .servicePlan) == [0])
    }

    @Test("Caps schedule at 60")
    func cap() {
        let item = Item(name: "Test")
        var coverages: [Coverage] = []
        for i in 0..<40 {
            coverages.append(Coverage(kind: .manufacturer, start: .now, end: Date(timeIntervalSinceNow: 86400 * Double(i + 40))))
        }
        item.coverages = coverages
        let scheduler = ReminderScheduler()
        let requests = scheduler.makeRequests(items: [item])
        #expect(requests.count <= 60)
        for r in requests { #expect(r.identifier.hasPrefix("cov-")) }
    }

    @Test("Pro preferences change which days and time reminders fire")
    func customLeads() {
        let item = Item(name: "TV")
        let end = Calendar.current.date(byAdding: .day, value: 120, to: .now)!
        let coverage = Coverage(kind: .manufacturer, start: .now, end: end)
        item.coverages = [coverage]

        var prefs = ReminderPreferences.standard
        prefs.warrantyLeads = [90, 14]
        prefs.hour = 18; prefs.minute = 30
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: true, saved: prefs)

        let requests = scheduler.makeRequests(items: [item])
        #expect(Set(requests.map(\.identifier)) == [
            ReminderScheduler.notificationID(coverageID: coverage.id, lead: 90),
            ReminderScheduler.notificationID(coverageID: coverage.id, lead: 14),
        ])
        for r in requests {
            let comps = (r.trigger as? UNCalendarNotificationTrigger)?.dateComponents
            #expect(comps?.hour == 18 && comps?.minute == 30)
        }
    }

    @Test("Free users always get the default schedule, even with saved preferences")
    func freeIgnoresSavedPreferences() {
        var prefs = ReminderPreferences.standard
        prefs.warrantyLeads = [90]
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: prefs)
        #expect(scheduler.preferences == .standard)
        #expect(scheduler.customRemindersEnabled == false)
    }

    @Test("One reminder per lead, soonest first, with the singular spelled out")
    func requestsPerLead() {
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let item = Item(name: "Kettle")
        let end = Calendar.current.date(byAdding: .day, value: 40, to: .now)!
        let coverage = Coverage(kind: .manufacturer, start: .now, end: end)
        item.coverages = [coverage]

        let requests = scheduler.makeRequests(items: [item])
        // Free defaults before a warranty ends are 30, 7 and 1 days.
        #expect(requests.map(\.identifier)
                == [30, 7, 1].map { ReminderScheduler.notificationID(coverageID: coverage.id, lead: $0) })

        let bodies = requests.map(\.content.body)
        #expect(bodies[0] == "Kettle: manufacturer warranty ends in 30 days.")
        #expect(bodies[1] == "Kettle: manufacturer warranty ends in 7 days.")
        #expect(requests[2].content.title == "Ending soon")
        #expect(bodies[2] == "Kettle: manufacturer warranty ends in 1 day.")
        // I4/G2 regression: concatenating a plural suffix produced "1 days".
        #expect(!bodies.contains { $0.contains("1 days") })

        let fireDates = requests.map { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture }
        #expect(fireDates == fireDates.sorted(), "the soonest reminder is scheduled first")
    }

    @Test("A service plan is announced from its next service date")
    func servicePlanReminder() {
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let item = Item(name: "Washer")
        let coverage = CoverageBuilder.make(kind: .servicePlan, start: .now, length: 1)
        item.coverages = [coverage]

        let requests = scheduler.makeRequests(items: [item])
        // The only free lead for a service plan is "on the day".
        #expect(requests.count == 1)
        #expect(requests[0].content.title == "Service due")
        #expect(requests[0].content.body == "Washer is due for service.")
        #expect(!requests[0].content.body.contains("0 days"))
    }

    @Test("Ended coverage and an interval-less service plan schedule nothing")
    func nothingToAnnounce() {
        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        let item = Item(name: "Kettle")
        item.coverages = [
            Coverage(kind: .servicePlan, start: .now, end: .distantFuture),   // no interval
            Coverage(kind: .manufacturer, start: .now, end: .now.addingTimeInterval(-86_400)),
        ]
        #expect(scheduler.makeRequests(items: [item]).isEmpty)
    }

    @Test("Custom one-off reminder is scheduled only for Pro")
    func customReminder() {
        let item = Item(name: "Water filter")
        item.customReminderDate = Calendar.current.date(byAdding: .day, value: 10, to: .now)
        let id = ReminderScheduler.customNotificationID(itemID: item.id)

        let scheduler = ReminderScheduler()
        scheduler.configure(isPro: false, saved: .standard)
        #expect(!scheduler.makeRequests(items: [item]).contains { $0.identifier == id })

        scheduler.configure(isPro: true, saved: .standard)
        #expect(scheduler.makeRequests(items: [item]).contains { $0.identifier == id })
        #expect(id.hasPrefix("cov-"))
    }
}
