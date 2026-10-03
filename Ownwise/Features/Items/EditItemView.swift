import SwiftUI
import SwiftData

struct EditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminder
    var item: Item?
    var onDone: () -> Void

    @State private var name = ""
    @State private var brand = ""
    @State private var serial = ""
    @State private var merchant = ""
    @State private var category: ItemCategory = .appliance
    @State private var purchaseDate: Date = .now
    @State private var warrantyMonthsText = ""
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name).accessibilityIdentifier(AXID.itemNameField)
                TextField("Brand", text: $brand).accessibilityIdentifier(AXID.itemBrandField)
                TextField("Serial number", text: $serial).accessibilityIdentifier(AXID.itemSerialField)
                TextField("Merchant", text: $merchant).accessibilityIdentifier(AXID.itemMerchantField)
                Picker("Category", selection: $category) {
                    ForEach(ItemCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                DatePicker("Purchased", selection: $purchaseDate, displayedComponents: .date)
                if item == nil {
                    TextField("Warranty (months)", text: $warrantyMonthsText).keyboardType(.numberPad)
                }
            }
            .navigationTitle(item == nil ? "New item" : "Edit item")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { onDone() }.accessibilityIdentifier(AXID.cancelButton) }
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { save() }.accessibilityIdentifier(AXID.saveItemButton) }
            }
            .onAppear {
                if let item {
                    name = item.name; brand = item.brand; serial = item.serialNumber
                    merchant = item.merchant; category = item.category; purchaseDate = item.purchaseDate
                }
            }
        }
    }

    func save() {
        guard !didSave else { return }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        didSave = true
        if let item {
            item.name = name; item.brand = brand; item.serialNumber = serial
            item.merchant = merchant; item.category = category; item.purchaseDate = purchaseDate
        } else {
            let new = Item(name: name)
            new.brand = brand; new.serialNumber = serial; new.merchant = merchant
            new.category = category; new.purchaseDate = purchaseDate
            if let m = Int(warrantyMonthsText), m > 0 {
                new.coverages = [Coverage(kind: .manufacturer, start: purchaseDate,
                                          end: Calendar.current.date(byAdding: .month, value: m, to: purchaseDate) ?? purchaseDate)]
            }
            modelContext.insert(new)
        }
        try? modelContext.save()
        Task { await reminder.rescheduleFromContext(modelContext) }
        onDone()
    }
}
