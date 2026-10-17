import Foundation
import SwiftData

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

    /// Curated chips offered wherever a reminder is set (add item, add coverage,
    /// item detail). Deliberately smaller than the Settings lists: at the moment
    /// of adding, a short human-scale choice beats a long day-count list.
    static func presets(for kind: CoverageKind) -> [Int] {
        switch kind {
        case .returnWindow: [14, 7, 3, 1, 0]
        case .servicePlan: [30, 7, 0]
        case .manufacturer, .extended, .insurance: [90, 30, 14, 7, 1, 0]
        }
    }

    /// The schedule a coverage gets when the user hasn't chosen one.
    static func defaultLeads(for kind: CoverageKind) -> [Int] { standard.leads(for: kind) }

    /// Sorted, de-duplicated and capped, so one item can't flood the user.
    static func normalizedLeads(_ leads: [Int]) -> [Int] {
        var seen = Set<Int>()
        return leads
            .filter { (0...maxLeadDays).contains($0) && seen.insert($0).inserted }
            .sorted(by: >)
            .prefix(maxLeads)
            .map { $0 }
    }

    /// Defensive ceiling on reminders per coverage. Must stay ≥ the largest
    /// preset set (6 for warranties) or a chip the user taps would not stick.
    static let maxLeads = 8

    /// Chip toggle. Returns the value to store: `nil` when the user is back on
    /// the smart default, because dropping the last chip should fall back to the
    /// default rather than leave an item completely unmonitored.
    static func toggling(_ day: Int, in current: [Int]) -> [Int]? {
        var next = normalizedLeads(current)
        if let index = next.firstIndex(of: day) {
            next.remove(at: index)
            return next.isEmpty ? nil : next
        }
        // At the ceiling, keep what the user already has instead of silently
        // dropping their smallest lead.
        guard next.count < maxLeads else { return current }
        next.append(day)
        return normalizedLeads(next)
    }

    /// Settings toggle. Turning every lead off is a legitimate global state
    /// ("Off"), so unlike a single item this one may return an empty list. The
    /// same ceiling applies, so both screens refuse the same additions.
    static func togglingGlobal(_ day: Int, in current: [Int]) -> [Int] {
        var next = normalizedLeads(current)
        if let index = next.firstIndex(of: day) {
            next.remove(at: index)
            return next
        }
        guard next.count < maxLeads else { return next }
        next.append(day)
        return normalizedLeads(next)
    }

    /// Adds a typed day count, ignoring it when already at the ceiling.
    static func adding(_ days: Int, to current: [Int]) -> [Int] {
        let next = normalizedLeads(current)
        guard next.count < maxLeads, !next.contains(days) else { return next }
        return normalizedLeads(next + [days])
    }

    /// Parses a user-typed day count; nil unless it's a whole number in 0...maxLeadDays.
    static func validLead(_ text: String) -> Int? {
        guard let days = Int(text.trimmingCharacters(in: .whitespaces)), (0...maxLeadDays).contains(days) else { return nil }
        return days
    }

    /// Copies one choice onto every coverage of the same kind and returns how many changed.
    ///
    /// This is "use this for every warranty" from the reminder editor. It lives here rather than in
    /// the view so the rule — same kind only, the edited coverage included, everything saved once —
    /// is unit-tested (I4), because getting it wrong silently changes reminders the user never
    /// opened.
    @MainActor
    static func apply(_ leads: [Int], toKind kind: CoverageKind, except coverage: Coverage,
                      in context: ModelContext) -> Int {
        let normalized = normalizedLeads(leads)
        var changed = 0
        for item in (try? context.fetch(FetchDescriptor<Item>())) ?? [] {
            for existing in item.coverages ?? [] where existing.kind == kind {
                guard existing.id != coverage.id else { continue }
                existing.reminderLeadDays = normalized
                changed += 1
            }
        }
        coverage.reminderLeadDays = normalized
        context.saveOrReport()
        return changed
    }

    /// The global setting, normalized exactly like a per-coverage choice so the
    /// chips an item shows lit are always the reminders that actually fire.
    func leads(for kind: CoverageKind) -> [Int] {        switch kind {
        case .returnWindow: return Self.normalizedLeads(returnLeads)
        case .manufacturer, .extended, .insurance: return Self.normalizedLeads(warrantyLeads)
        case .servicePlan: return [0]
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

    /// Chip label. Weeks and months read faster than day counts at a glance
    /// ("1 month before" beats "30 days before").
    static func chipLabel(_ days: Int) -> String {
        switch days {
        case 0: String(localized: "On the day")
        case 1: String(localized: "1 day before")
        case 7: String(localized: "1 week before")
        case 14: String(localized: "2 weeks before")
        case 30: String(localized: "1 month before")
        case 60: String(localized: "2 months before")
        case 90: String(localized: "3 months before")
        default: String(localized: "\(days) days before")
        }
    }

    /// Just the unit, for building a sentence: "1 month", "2 weeks", "3 days".
    static func phraseUnit(_ days: Int) -> String {
        switch days {
        case 7: String(localized: "1 week")
        case 14: String(localized: "2 weeks")
        case 30: String(localized: "1 month")
        case 60: String(localized: "2 months")
        case 90: String(localized: "3 months")
        default: days == 1 ? String(localized: "1 day") : String(localized: "\(days) days")
        }
    }

    /// e.g. "1 month, 1 week and 1 day before" / "3 and 1 days before" /
    /// "1 month before, plus on the day" / "Off".
    static func presetPhrase(_ leads: [Int]) -> String {
        let sorted = normalizedLeads(leads)
        let days = sorted.filter { $0 > 0 }
        let onTheDay = sorted.contains(0)
        guard !days.isEmpty else {
            return onTheDay ? String(localized: "on the day") : String(localized: "Off")
        }
        // Spell out weeks/months only when the whole set is coarse enough for it;
        // a mix like 30 + 3 + 1 reads best as plain day counts.
        let spellOut = days.allSatisfy { [7, 14, 30, 60, 90].contains($0) }
        let list = (spellOut ? days.map(phraseUnit) : days.map(String.init)).formatted(.list(type: .and))
        let beforePart: String
        if days == [1] {
            beforePart = String(localized: "1 day before")
        } else if spellOut {
            beforePart = String(localized: "\(list) before")
        } else {
            beforePart = String(localized: "\(list) days before")
        }
        // "…before and on the day" doubles up on "and", so join with "plus".
        return onTheDay ? String(localized: "\(beforePart), plus on the day") : beforePart
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

    /// Shown under Settings → Reminders. One line, and only about the defaults:
    /// the per-kind breakdown lives on the Reminders screen itself.
    var summary: String {
        let time = fireDate(on: .now).formatted(date: .omitted, time: .shortened)
        return String(localized: "Defaults: \(Self.leadsPhrase(warrantyLeads)), at \(time).")
    }
}
