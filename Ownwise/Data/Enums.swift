import Foundation

enum ItemCategory: String, CaseIterable, Codable, Sendable {
    case appliance, electronics, mobile, computer, furniture, vehicle, other

    var label: String {
        switch self {
        case .appliance: String(localized: "Appliance", comment: "Item category")
        case .electronics: String(localized: "Electronics", comment: "Item category")
        case .mobile: String(localized: "Mobile", comment: "Item category")
        case .computer: String(localized: "Computer", comment: "Item category")
        case .furniture: String(localized: "Furniture", comment: "Item category")
        case .vehicle: String(localized: "Vehicle", comment: "Item category")
        case .other: String(localized: "Other", comment: "Item category")
        }
    }
}

enum CoverageKind: String, CaseIterable, Codable, Sendable {
    case returnWindow, manufacturer, extended, servicePlan, insurance

    var label: String {
        switch self {
        case .returnWindow: String(localized: "Return window", comment: "Coverage kind")
        case .manufacturer: String(localized: "Manufacturer warranty", comment: "Coverage kind")
        case .extended: String(localized: "Extended warranty", comment: "Coverage kind")
        case .servicePlan: String(localized: "Service plan", comment: "Coverage kind")
        case .insurance: String(localized: "Insurance", comment: "Coverage kind")
        }
    }
}

enum AttachmentKind: String, CaseIterable, Codable, Sendable {
    case receipt, invoice, warrantyCard, manual, photo

    var label: String {
        switch self {
        case .receipt: String(localized: "Receipt", comment: "Attachment kind")
        case .invoice: String(localized: "Invoice", comment: "Attachment kind")
        case .warrantyCard: String(localized: "Warranty card", comment: "Attachment kind")
        case .manual: String(localized: "Manual", comment: "Attachment kind")
        case .photo: String(localized: "Photo", comment: "Attachment kind")
        }
    }
}

enum CoverageStatus: Sendable, Equatable {
    case active
    case expiringSoon(days: Int)
    case expired
    case serviceDue

    var label: String {
        switch self {
        case .active: String(localized: "Covered", comment: "Coverage status badge")
        case .expiringSoon(let days): String(localized: "\(days)d left", comment: "Coverage status badge, e.g. 30d left")
        case .expired: String(localized: "Expired", comment: "Coverage status badge")
        case .serviceDue: String(localized: "Service due", comment: "Coverage status badge")
        }
    }
}

/// The one status to show for an item: the most urgent live coverage.
/// "Expired" only when nothing is still covered (an ended return window doesn't
/// make an item with an active warranty look expired).
func overallStatus(of coverages: [Coverage], now: Date,
                   soonDays: Int = LibraryPreferences.soonDays,
                   calendar: Calendar = .current) -> CoverageStatus? {
    func rank(_ s: CoverageStatus) -> Int {
        switch s { case .serviceDue: 0; case .expiringSoon: 1; case .active: 2; case .expired: 3 }
    }
    return coverages.map { coverageStatus(of: $0, now: now, soonDays: soonDays, calendar: calendar) }
        .min { rank($0) < rank($1) }
}

/// Pure status logic (unit-tested). Service-due takes precedence for service plans.
/// `soonDays` defaults to the user's chosen horizon (E7).
func coverageStatus(of c: Coverage, now: Date,
                    soonDays: Int = LibraryPreferences.soonDays,
                    calendar: Calendar = .current) -> CoverageStatus {
    if c.kind == .servicePlan, let next = c.nextServiceDate {
        if next <= now { return .serviceDue }
        return .active
    }
    if c.endDate < now { return .expired }
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: c.endDate)).day ?? 0
    if days <= soonDays { return .expiringSoon(days: max(days, 0)) }
    return .active
}
