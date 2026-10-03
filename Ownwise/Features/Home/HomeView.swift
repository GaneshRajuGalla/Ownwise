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
        let coverages = items.flatMap { $0.coverages ?? [] }
        var fine = 0, expiringReturn = 0, expiringOther = 0, serviceDue = 0
        for cov in coverages {
            switch coverageStatus(of: cov, now: .now) {
            case .expiringSoon:
                if cov.kind == .returnWindow { expiringReturn += 1 } else { expiringOther += 1 }
            case .serviceDue:
                serviceDue += 1
            case .active:
                fine += 1
            case .expired:
                break
            }
        }
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Space.m) {
            chip("Return soon", "\(expiringReturn)", .orange) { selectedFilter = .expiring }
            chip("Expiring", "\(expiringOther)", .orange) { selectedFilter = .expiring }
            chip("Service due", "\(serviceDue)", .blue) { selectedFilter = .serviceDue }
            chip("Covered", "\(fine)", .green) { selectedFilter = .active }
        }
    }

    @State private var selectedFilter: SearchView.StatusFilter?

    func chip(_ title: String, _ value: String, _ color: Color, onTap: @escaping () -> Void) -> some View {
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
        let flagged = items.filter { item in
            (item.coverages ?? []).contains { c in
                switch coverageStatus(of: c, now: .now) {
                case .expiringSoon, .expired, .serviceDue: true
                case .active: false
                }
            }
        }
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
