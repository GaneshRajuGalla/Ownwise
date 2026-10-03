import SwiftUI
import SwiftData

struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(ReminderScheduler.self) private var reminder
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]

    @State private var showAdd = false
    @State private var categoryFilter: ItemCategory?
    @State private var showPaywall = false

    var filtered: [Item] {
        guard let categoryFilter else { return items }
        return items.filter { $0.category == categoryFilter }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped.keys.sorted(by: { $0.label < $1.label }), id: \.self) { category in
                    Section(category.label) {
                        ForEach(grouped[category] ?? []) { item in
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AXID.itemRowPrefix + item.id.uuidString)
                        }
                        .onDelete { offsets in delete(in: category, offsets: offsets) }
                    }
                }
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if store.canAddItem(count: items.count) { showAdd = true }
                        else { showPaywall = true }
                    } label: { Image(systemName: "plus") }
                    .accessibilityIdentifier(AXID.addItemButton)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All categories") { categoryFilter = nil }
                        ForEach(ItemCategory.allCases, id: \.self) { c in
                            Button(c.label) { categoryFilter = c }
                        }
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
                }
            }
            .overlay {
                if items.isEmpty {
                    EmptyStateView(title: "No items yet", message: "Scan a receipt or add an item manually.", systemImage: "shippingbox", actionTitle: "Add item") { showAdd = true }
                }
            }
            .sheet(isPresented: $showAdd) {
                EditItemView(item: nil) { showAdd = false }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    var grouped: [ItemCategory: [Item]] {
        Dictionary(grouping: filtered, by: \.category)
    }

    func delete(in category: ItemCategory, offsets: IndexSet) {
        let list = grouped[category] ?? []
        for i in offsets { modelContext.delete(list[i]) }
        try? modelContext.save()
        Task { await reminder.rescheduleFromContext(modelContext) }
    }
}
