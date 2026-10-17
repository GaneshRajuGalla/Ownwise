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
    @State private var pendingDelete: Item?

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
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { pendingDelete = item } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier(AXID.deleteSwipeButton)
                            }
                        }
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
                    .accessibilityIdentifier(AXID.categoryMenu)
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
            // Deleting an item takes its coverages, receipts and photos with it (cascade),
            // so it asks first — the swipe alone must never destroy anything.
            .confirmationDialog(
                pendingDelete.map { "Delete \($0.name)?" } ?? "Delete item?",
                isPresented: deleteDialogPresented,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { confirmDelete() }
                    .accessibilityIdentifier(AXID.deleteItemButton)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its coverages, receipts and photos are deleted with it.")
            }
        }
    }

    private var deleteDialogPresented: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    var grouped: [ItemCategory: [Item]] {
        Dictionary(grouping: filtered, by: \.category)
    }

    private func confirmDelete() {
        guard let item = pendingDelete else { return }
        pendingDelete = nil
        LibraryActions.delete(item, in: modelContext)
        Task { await reminder.rescheduleFromContext(modelContext) }
    }
}
