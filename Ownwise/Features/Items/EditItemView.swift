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
    @State private var supportPhone = ""
    @State private var notes = ""
    @State private var category: ItemCategory = .appliance
    @State private var purchaseDate: Date = .now
    @State private var warrantyMonthsText = ""
    @State private var returnDaysText = ""
    @State private var modelNumber = ""
    @State private var orderNumber = ""
    @State private var priceText = ""
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
                TextField("Price (\(currencyCode))", text: $priceText).keyboardType(.decimalPad)
                TextField("Model number", text: $modelNumber)
                TextField("Order number", text: $orderNumber)
                if item == nil {
                    TextField("Return window (days)", text: $returnDaysText).keyboardType(.numberPad)
                    TextField("Warranty (months)", text: $warrantyMonthsText).keyboardType(.numberPad)
                }
                TextField("Support phone", text: $supportPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(1...4)
            }
            .navigationTitle(item == nil ? "New item" : "Edit item")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { onDone() }.accessibilityIdentifier(AXID.cancelButton) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier(AXID.saveItemButton)
                }
            }
            .onAppear {
                if let item {
                    name = item.name; brand = item.brand; serial = item.serialNumber
                    merchant = item.merchant; category = item.category; purchaseDate = item.purchaseDate
                    supportPhone = item.supportPhone; notes = item.notes
                    modelNumber = item.modelNumber; orderNumber = item.orderNumber
                    priceText = item.priceMinor.map { Money.plainString($0, currencyCode: item.currencyCode) } ?? ""
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
            item.supportPhone = supportPhone; item.notes = notes
            item.modelNumber = modelNumber; item.orderNumber = orderNumber
            item.priceMinor = parsedPrice(currencyCode: item.currencyCode)
        } else {
            let new = Item(name: name)
            new.brand = brand; new.serialNumber = serial; new.merchant = merchant
            new.category = category; new.purchaseDate = purchaseDate
            new.supportPhone = supportPhone; new.notes = notes
            new.modelNumber = modelNumber; new.orderNumber = orderNumber
            new.priceMinor = parsedPrice(currencyCode: new.currencyCode)
            if let d = Int(returnDaysText), d > 0 {
                new.coverages = (new.coverages ?? []) + [Coverage(kind: .returnWindow, start: purchaseDate,
                                                                  end: Calendar.current.date(byAdding: .day, value: d, to: purchaseDate) ?? purchaseDate)]
            }
            if let m = Int(warrantyMonthsText), m > 0 {
                new.coverages = (new.coverages ?? []) + [Coverage(kind: .manufacturer, start: purchaseDate,
                                          end: Calendar.current.date(byAdding: .month, value: m, to: purchaseDate) ?? purchaseDate)]
            }
            modelContext.insert(new)
        }
        try? modelContext.save()
        Task { await reminder.rescheduleFromContext(modelContext) }
        onDone()
    }

    private var currencyCode: String {
        item?.currencyCode ?? (Locale.current.currency?.identifier ?? "USD")
    }

    /// Accepts "1299.50", "1299,50" or "1,299.50"; empty clears the price.
    private func parsedPrice(currencyCode: String) -> Int? {
        let trimmed = priceText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let amount = ReceiptParser().parseAmount(trimmed), amount >= 0 else { return nil }
        return Money.minorUnits(amount, currencyCode: currencyCode)
    }
}
