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
