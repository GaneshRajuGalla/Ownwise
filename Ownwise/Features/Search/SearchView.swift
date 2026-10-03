import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var items: [Item]
    @State private var query = ""
    @State private var statusFilter: StatusFilter
    init(statusFilter: StatusFilter = .all) {
        _statusFilter = State(initialValue: statusFilter)
    }

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case expiring = "Expiring"
        case expired = "Expired"
        case serviceDue = "Service due"
        var id: String { rawValue }
    }

    var results: [Item] {
        items.filter { item in
            let matchesQuery = query.isEmpty
                || item.name.localizedStandardContains(query)
                || item.brand.localizedStandardContains(query)
                || item.modelNumber.localizedStandardContains(query)
                || item.serialNumber.localizedStandardContains(query)
                || item.merchant.localizedStandardContains(query)
                || item.orderNumber.localizedStandardContains(query)
                || (item.attachments ?? []).contains { $0.ocrText.localizedStandardContains(query) }
            let matchesStatus: Bool = {
                switch statusFilter {
                case .all: return true
                case .active: return (item.coverages ?? []).contains { coverageStatus(of: $0, now: .now) == .active }
                case .expiring: return (item.coverages ?? []).contains { if case .expiringSoon = coverageStatus(of: $0, now: .now) { true } else { false } }
                case .expired: return (item.coverages ?? []).contains { coverageStatus(of: $0, now: .now) == .expired }
                case .serviceDue: return (item.coverages ?? []).contains { coverageStatus(of: $0, now: .now) == .serviceDue }
                }
            }()
            return matchesQuery && matchesStatus
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { item in
                NavigationLink { ItemDetailView(item: item) } label: { ItemRow(item: item) }.buttonStyle(.plain)
                    .accessibilityIdentifier(AXID.itemRowPrefix + item.id.uuidString)
            }
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .accessibilityIdentifier(AXID.searchField)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                        ForEach(StatusFilter.allCases) { f in
                            Button(f.rawValue) { statusFilter = f }
                                .accessibilityIdentifier(f == .active ? AXID.filterActive : (f == .expired ? AXID.filterExpired : "filter_\(f.rawValue.lowercased())"))
                        }
                    }
                }
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }
}
