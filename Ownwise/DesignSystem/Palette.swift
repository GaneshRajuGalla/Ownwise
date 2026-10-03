import SwiftUI

enum Palette {
    static let active = Color.green
    static let expiringSoon = Color.orange
    static let expired = Color.red
    static let serviceDue = Color.blue

    static func color(for status: CoverageStatus) -> Color {
        switch status {
        case .active: active
        case .expiringSoon: expiringSoon
        case .expired: expired
        case .serviceDue: serviceDue
        }
    }

    static func icon(for status: CoverageStatus) -> String {
        switch status {
        case .active: "checkmark.seal.fill"
        case .expiringSoon: "clock.badge.exclamationmark"
        case .expired: "xmark.seal.fill"
        case .serviceDue: "wrench.and.screwdriver.fill"
        }
    }
}
