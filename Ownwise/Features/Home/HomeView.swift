import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var items: [Item]
    @State private var showScan = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(title: "Nothing here yet", message: "Scan your first receipt to get started.", systemImage: "doc.viewfinder", actionTitle: "Scan a receipt") { showScan = true }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DS.Space.l) {
                            chips
                            needsAttention
                        }
                        .padding(DS.Space.l)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ownwise")
            .sheet(item: $selectedFilter) { filter in
                SearchView(statusFilter: filter)
            }
            .sheet(isPresented: $showScan) { ScanFlow() }
        }
    }

    var chips: some View {
        // Counting lives in LibraryInsights, so it is testable and not recomputed inline (H3).
        let counts = LibraryInsights.counts(of: items, now: .now)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.m) {
            chip("Return soon", "\(counts.expiringReturn)", .orange) { selectedFilter = .expiring }
            chip("Expiring", "\(counts.expiringOther)", .orange) { selectedFilter = .expiring }
            chip("Service due", "\(counts.serviceDue)", .blue) { selectedFilter = .serviceDue }
            chip("Covered", "\(counts.covered)", .green) { selectedFilter = .active }
        }
    }

    @State private var selectedFilter: SearchView.StatusFilter?

    func chip(_ title: LocalizedStringKey, _ value: String, _ color: Color, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            SectionCard {
                HStack {
                    Text(value).font(Typography.daysLeft()).foregroundStyle(color)
                    Spacer()
                }
                Text(title).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    var needsAttention: some View {
        // Only things the user can still act on; long-expired coverage isn't "attention".
        let flagged = LibraryInsights.needsAttention(in: items, now: .now)
        return SectionCard(title: "Needs attention") {
            if flagged.isEmpty {
                Text("All covered. We'll let you know before anything expires.").foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(flagged) { item in
                    NavigationLink { ItemDetailView(item: item) } label: {
                        ItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier(AXID.needsAttentionList)
    }
}
