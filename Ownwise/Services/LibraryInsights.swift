import Foundation

/// What the home screen says about the library.
///
/// The counting rules used to live inside `HomeView`'s body, where they ran on every layout pass
/// and could not be tested (H3). They are pure functions of the items and a date, so they are
/// unit-tested directly.
@MainActor
enum LibraryInsights {

    /// Coverage counts for the four chips.
    struct CoverageCounts: Equatable, Sendable {
        var expiringReturn = 0
        var expiringOther = 0
        var serviceDue = 0
        var covered = 0
    }

    static func counts(of items: [Item], now: Date = .now) -> CoverageCounts {
        var result = CoverageCounts()
        for item in items {
            for coverage in item.coverages ?? [] {
                switch coverageStatus(of: coverage, now: now) {
                case .expiringSoon:
                    if coverage.kind == .returnWindow {
                        result.expiringReturn += 1
                    } else {
                        result.expiringOther += 1
                    }
                case .serviceDue:
                    result.serviceDue += 1
                case .active:
                    result.covered += 1
                case .expired:
                    break
                }
            }
        }
        return result
    }

    /// Items with something still actionable: expiring soon, or due for service. Long-expired
    /// coverage is not "attention", because there is nothing left to do about it.
    static func needsAttention(in items: [Item], now: Date = .now) -> [Item] {
        items.filter { item in
            (item.coverages ?? []).contains { coverage in
                switch coverageStatus(of: coverage, now: now) {
                case .expiringSoon, .serviceDue: true
                case .active, .expired: false
                }
            }
        }
    }
}
