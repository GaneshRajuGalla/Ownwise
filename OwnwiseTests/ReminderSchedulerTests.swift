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
}
