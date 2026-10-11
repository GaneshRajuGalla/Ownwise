import Foundation

enum ItemCategory: String, CaseIterable, Codable, Sendable {
    case appliance, electronics, mobile, computer, furniture, vehicle, other

    var label: String {
        switch self {
        case .appliance: "Appliance"
        case .electronics: "Electronics"
        case .mobile: "Mobile"
        case .computer: "Computer"
        case .furniture: "Furniture"
        case .vehicle: "Vehicle"
        case .other: "Other"
        }
    }
}

enum CoverageKind: String, CaseIterable, Codable, Sendable {
    case returnWindow, manufacturer, extended, servicePlan, insurance

    var label: String {
        switch self {
        case .returnWindow: "Return window"
        case .manufacturer: "Manufacturer warranty"
        case .extended: "Extended warranty"
        case .servicePlan: "Service plan"
        case .insurance: "Insurance"
        }
    }
}

enum AttachmentKind: String, CaseIterable, Codable, Sendable {
    case receipt, invoice, warrantyCard, manual, photo

    var label: String {
        switch self {
        case .receipt: "Receipt"
        case .invoice: "Invoice"
        case .warrantyCard: "Warranty card"
        case .manual: "Manual"
        case .photo: "Photo"
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
        case .active: "Covered"
        case .expiringSoon(let days): "\(days)d left"
        case .expired: "Expired"
        case .serviceDue: "Service due"
        }
    }
}

/// The one status to show for an item: the most urgent live coverage.
/// "Expired" only when nothing is still covered (an ended return window doesn't
/// make an item with an active warranty look expired).
func overallStatus(of coverages: [Coverage], now: Date, calendar: Calendar = .current) -> CoverageStatus? {
    func rank(_ s: CoverageStatus) -> Int {
        switch s { case .serviceDue: 0; case .expiringSoon: 1; case .active: 2; case .expired: 3 }
    }
    return coverages.map { coverageStatus(of: $0, now: now, calendar: calendar) }.min { rank($0) < rank($1) }
}

/// Pure status logic (unit-tested). Service-due takes precedence for service plans.
func coverageStatus(of c: Coverage, now: Date, soonDays: Int = 30, calendar: Calendar = .current) -> CoverageStatus {
    if c.kind == .servicePlan, let next = c.nextServiceDate {
        if next <= now { return .serviceDue }
        return .active
    }
    if c.endDate < now { return .expired }
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: c.endDate)).day ?? 0
    if days <= soonDays { return .expiringSoon(days: max(days, 0)) }
    return .active
}
