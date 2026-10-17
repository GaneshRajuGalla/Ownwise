import Foundation

/// Searching the library: the text match and the status filter.
///
/// This lived in `SearchView`'s body, where it ran on every keystroke and could only be exercised
/// through a UI test whose every assertion was optional (I1, I4).
@MainActor
enum LibrarySearch {

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case expiring = "Expiring"
        case expired = "Expired"
        case serviceDue = "Service due"
        var id: String { rawValue }
    }

    /// Items matching both the typed text and the status filter.
    ///
    /// A blank (or whitespace-only) query means "no text filter", not "match nothing".
    static func filter(_ items: [Item], query: String, status: StatusFilter = .all,
                       now: Date = .now) -> [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return items.filter { item in
            matches(item, query: trimmed) && matches(item, status: status, now: now)
        }
    }

    /// What a person would search by: the fields they typed in, plus the OCR text of any receipt,
    /// so an item can be found by something that is only printed on its receipt.
    static func matches(_ item: Item, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return item.name.localizedStandardContains(query)
            || item.brand.localizedStandardContains(query)
            || item.modelNumber.localizedStandardContains(query)
            || item.serialNumber.localizedStandardContains(query)
            || item.merchant.localizedStandardContains(query)
            || item.orderNumber.localizedStandardContains(query)
            || (item.attachments ?? []).contains { $0.ocrText.localizedStandardContains(query) }
    }

    static func matches(_ item: Item, status: StatusFilter, now: Date = .now) -> Bool {
        switch status {
        case .all:
            return true
        case .active:
            return covers(item, now: now) { $0 == .active }
        case .expiring:
            return covers(item, now: now) { s in
                if case .expiringSoon = s { true } else { false }
            }
        case .expired:
            return covers(item, now: now) { $0 == .expired }
        case .serviceDue:
            return covers(item, now: now) { $0 == .serviceDue }
        }
    }

    private static func covers(_ item: Item, now: Date, _ isMatch: (CoverageStatus) -> Bool) -> Bool {
        (item.coverages ?? []).contains { isMatch(coverageStatus(of: $0, now: now)) }
    }
}
