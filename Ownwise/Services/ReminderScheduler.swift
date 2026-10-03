import Foundation
import SwiftData
import UserNotifications
import Observation

@Observable
@MainActor
final class ReminderScheduler {
    static let taskID = "com.ownwise.Ownwise.refresh"
    static let maxScheduled = 60

    var authorizationGranted = false

    /// Which leads to schedule for each coverage end.
    static func leads(for kind: CoverageKind) -> [Int] {
        switch kind {
        case .returnWindow: return [3, 1]
        case .manufacturer, .extended, .insurance: return [30, 7, 1]
        case .servicePlan: return [0]
        }
    }

    static func notificationID(coverageID: UUID, lead: Int) -> String {
        "cov-\(coverageID.uuidString)-\(lead)"
    }

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            authorizationGranted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        } else {
            authorizationGranted = settings.authorizationStatus == .authorized
        }
    }

    func grantPermissionForUITesting() async {
        authorizationGranted = true
    }

    /// Fetches all items from the context and rebuilds the schedule.
    func rescheduleFromContext(_ context: ModelContext) async {
        let items = (try? context.fetch(FetchDescriptor<Item>())) ?? []
        await rescheduleAll(items: items)
    }

    /// Builds the (capped) request list. Pure value — safe to unit test.
    func makeRequests(items: [Item]) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []
        for item in items {
            for coverage in item.coverages ?? [] {
                switch coverage.kind {
                case .servicePlan:
                    if let next = coverage.nextServiceDate, next > .now {
                        requests.append(makeRequest(coverage: coverage, item: item, lead: 0, date: atTenAM(next), title: "Service due", body: "\(item.name) is due for service."))
                    }
                default:
                    for lead in Self.leads(for: coverage.kind) {
                        guard let fire = Calendar.current.date(byAdding: .day, value: -lead, to: coverage.endDate), fire > .now else { continue }
                        let body = lead == 0
                            ? "\(item.name): coverage ends today."
                            : "\(item.name): \(coverage.kind.label.lowercased()) ends in \(lead) day\(lead == 1 ? "" : "s")."
                        requests.append(makeRequest(coverage: coverage, item: item, lead: lead, date: atTenAM(fire), title: lead <= 1 ? "Ending soon" : "Upcoming end", body: body))
                    }
                }
            }
        }
        return requests
            .sorted { triggerDate($0) < triggerDate($1) }
            .prefix(Self.maxScheduled)
            .map { $0 }
    }

    /// Removes only IDs we own, schedules the nearest `maxScheduled` leads.
    func rescheduleAll(items: [Item]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix("cov-") }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        for r in makeRequests(items: items) { try? await center.add(r) }
    }

    private func atTenAM(_ date: Date) -> Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date
    }

    private func triggerDate(_ r: UNNotificationRequest) -> Date {
        (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }

    private func makeRequest(coverage: Coverage, item: Item, lead: Int, date: Date, title: String, body: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: Self.notificationID(coverageID: coverage.id, lead: lead), content: content, trigger: trigger)
    }
}
