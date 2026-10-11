import Foundation

/// When coverage reminders fire. Free users always get `.standard`
/// (smart defaults); Ownwise Pro users can choose their own days and time.
struct ReminderPreferences: Codable, Sendable, Equatable {
    /// 9:00 local: early enough to act the same day (return a product, call support).
    var hour: Int = 9
    var minute: Int = 0
    /// Days before a return window closes.
    var returnLeads: [Int] = [3, 1]
    /// Days before a manufacturer / extended warranty or insurance ends.
    var warrantyLeads: [Int] = [30, 7, 1]

    static let standard = ReminderPreferences()
    static let returnLeadOptions = [14, 7, 3, 2, 1, 0]
    static let warrantyLeadOptions = [90, 60, 30, 14, 7, 3, 1, 0]
    static let maxLeadDays = 365
    private static let storageKey = "reminderPreferences"

    /// Parses a user-typed day count; nil unless it's a whole number in 0...maxLeadDays.
    static func validLead(_ text: String) -> Int? {
        guard let days = Int(text.trimmingCharacters(in: .whitespaces)), (0...maxLeadDays).contains(days) else { return nil }
        return days
    }

    func leads(for kind: CoverageKind) -> [Int] {
        switch kind {
        case .returnWindow: returnLeads.sorted(by: >)
        case .manufacturer, .extended, .insurance: warrantyLeads.sorted(by: >)
        case .servicePlan: [0]
        }
    }

    /// The fire date for a reminder on `day`, at the preferred time.
    func fireDate(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    // MARK: Persistence

    static func load(from defaults: UserDefaults = .standard) -> ReminderPreferences {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(ReminderPreferences.self, from: data) else { return .standard }
        return saved
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.storageKey) }
    }

    // MARK: Text

    static func leadLabel(_ days: Int) -> String {
        switch days {
        case 0: String(localized: "On the day")
        case 1: String(localized: "1 day before")
        default: String(localized: "\(days) days before")
        }
    }

    /// e.g. "30, 7 and 1 days before" / "3 days before and on the day" / "Off".
    static func leadsPhrase(_ leads: [Int]) -> String {
        let days = Set(leads).filter { $0 > 0 }.sorted(by: >)
        var parts: [String] = []
        if !days.isEmpty {
            let list = days.map(String.init).formatted(.list(type: .and))
            parts.append(days == [1] ? String(localized: "1 day before") : String(localized: "\(list) days before"))
        }
        if leads.contains(0) { parts.append(String(localized: "on the day")) }
        return parts.isEmpty ? String(localized: "Off") : parts.formatted(.list(type: .and))
    }

    var summary: String {
        let time = fireDate(on: .now).formatted(date: .omitted, time: .shortened)
        return String(localized: "Return windows: \(Self.leadsPhrase(returnLeads)). Warranties: \(Self.leadsPhrase(warrantyLeads)). Sent at \(time).")
    }
}
