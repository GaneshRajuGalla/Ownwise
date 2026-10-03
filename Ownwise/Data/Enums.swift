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
