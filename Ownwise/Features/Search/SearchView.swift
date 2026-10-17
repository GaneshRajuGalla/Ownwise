import SwiftUI
import SwiftData

struct SearchView: View {
    @Query private var items: [Item]
    @State private var query = ""
    @State private var statusFilter: StatusFilter
    init(statusFilter: StatusFilter = .all) {
        _statusFilter = State(initialValue: statusFilter)
    }

    /// The filter cases live with the matching rules, so they can be tested directly (I4).
    typealias StatusFilter = LibrarySearch.StatusFilter

    var results: [Item] {
        LibrarySearch.filter(items, query: query, status: statusFilter, now: .now)
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
                    // Never "No results for """ — say which of the three empty states this is.
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        ContentUnavailableView.search(text: query)
                    } else if statusFilter != .all {
                        EmptyStateView(title: "Nothing matches this filter",
                                       message: "Try another filter, or clear it to see everything.",
                                       systemImage: "line.3.horizontal.decrease.circle")
                    } else {
                        EmptyStateView(title: "Nothing to search yet",
                                       message: "Add an item and it will show up here.",
                                       systemImage: "magnifyingglass")
                    }
                }
            }
        }
    }
}
