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
    /// Days and time reminders fire. `.standard` unless the user has Pro.
    private(set) var preferences: ReminderPreferences = .standard
    /// Per-item custom reminders are a Pro feature.
    private(set) var customRemindersEnabled = false

    /// Default (free) leads for each coverage end.
    static func leads(for kind: CoverageKind) -> [Int] {
        ReminderPreferences.standard.leads(for: kind)
    }

    /// What this coverage will actually remind on: the user's pick for this one
    /// coverage, else the global setting (Pro), else the smart default.
    func leads(for coverage: Coverage) -> [Int] {
        if let chosen = coverage.reminderLeadDays, !chosen.isEmpty {
            return ReminderPreferences.normalizedLeads(chosen)
        }
        return preferences.leads(for: coverage.kind)
    }

    static func notificationID(coverageID: UUID, lead: Int) -> String {
        "cov-\(coverageID.uuidString)-\(lead)"
    }

    static func customNotificationID(itemID: UUID) -> String {
        "cov-custom-\(itemID.uuidString)"
    }

    /// Pro users get their saved preferences and custom reminders; everyone else the smart defaults.
    func configure(isPro: Bool, saved: ReminderPreferences = .load()) {
        preferences = isPro ? saved : .standard
        customRemindersEnabled = isPro
    }

    func requestPermissionIfNeeded() async {
        // UI tests never show the system prompt (it would block the flow).
        if LaunchEnvironment.isUITesting { authorizationGranted = true; return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            authorizationGranted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        } else {
            authorizationGranted = settings.authorizationStatus == .authorized
        }
    }

    /// Reads the current permission without prompting (used at launch).
    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationGranted = settings.authorizationStatus == .authorized
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
    /// `calendar` is injectable so date handling (DST, time zones) is testable;
    /// triggers are built from components without a time zone, so a reminder
    /// fires at the same wall-clock time in whatever zone the user is in.
    func makeRequests(items: [Item], calendar: Calendar = .current) -> [UNNotificationRequest] {
        let now = Date.now
        var requests: [UNNotificationRequest] = []
        for item in items {
            if customRemindersEnabled, let date = item.customReminderDate, date > now {
                let content = UNMutableNotificationContent()
                content.title = String(localized: "Reminder")
                content.body = item.notes.isEmpty ? item.name : "\(item.name): \(item.notes)"
                content.sound = .default
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                requests.append(UNNotificationRequest(identifier: Self.customNotificationID(itemID: item.id), content: content,
                                                      trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
            for coverage in item.coverages ?? [] {
                let isService = coverage.kind == .servicePlan
                let base = isService ? coverage.nextServiceDate : coverage.endDate
                // Long-expired coverage and unscheduled service plans have nothing to announce.
                guard let base, base > now else { continue }
                for lead in leads(for: coverage) {
                    guard let day = calendar.date(byAdding: .day, value: -lead, to: base) else { continue }
                    let fire = preferences.fireDate(on: day, calendar: calendar)
                    // A trigger whose date has already passed never fires.
                    guard fire > now else { continue }
                    let title: String
                    let body: String
                    if isService {
                        title = String(localized: "Service due")
                        body = lead == 0
                            ? String(localized: "\(item.name) is due for service.")
                            : String(localized: "\(item.name) is due for service in \(lead) day\(lead == 1 ? "" : "s").")
                    } else {
                        title = lead <= 1 ? String(localized: "Ending soon") : String(localized: "Upcoming end")
                        body = lead == 0
                            ? String(localized: "\(item.name): coverage ends today.")
                            : String(localized: "\(item.name): \(coverage.kind.label.lowercased()) ends in \(lead) day\(lead == 1 ? "" : "s").")
                    }
                    requests.append(makeRequest(coverage: coverage, item: item, lead: lead, date: fire, title: title, body: body, calendar: calendar))
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

    private func triggerDate(_ r: UNNotificationRequest) -> Date {
        (r.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }

    private func makeRequest(coverage: Coverage, item: Item, lead: Int, date: Date, title: String, body: String, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: Self.notificationID(coverageID: coverage.id, lead: lead), content: content, trigger: trigger)
    }
}
