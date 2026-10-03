import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State var model: ReviewModel
    @State private var didSave = false
    var onSaved: () -> Void

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $model.name).accessibilityIdentifier(AXID.reviewNameField)
                TextField("Merchant", text: $model.merchant).accessibilityIdentifier(AXID.reviewMerchantField)
                TextField("Brand", text: $model.brand)
                TextField("Model number", text: $model.modelNumber)
                TextField("Serial number", text: $model.serialNumber)
                Picker("Category", selection: $model.category) {
                    ForEach(ItemCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                DatePicker("Purchased", selection: $model.purchaseDate, displayedComponents: .date)
                    .accessibilityIdentifier(AXID.reviewDateField)
            }
            Section("Price") {
                TextField("Total", text: $model.totalText).keyboardType(.decimalPad).accessibilityIdentifier(AXID.reviewTotalField)
                TextField("Currency code", text: $model.currencyCode)
                TextField("Order number", text: $model.orderNumber)
            }
            Section("Coverage") {
                TextField("Warranty (months)", text: $model.warrantyMonthsText).keyboardType(.numberPad)
                TextField("Return window (days)", text: $model.returnDaysText).keyboardType(.numberPad)
            }
            if !model.fieldsFromAI.isEmpty {
                Section {
                    Label("Fields marked ✦ were suggested on-device. Please confirm.", systemImage: "sparkles")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Save item") {
                    guard !didSave else { return }
                    didSave = true
                    model.save(into: modelContext)
                    onSaved()
                }
                .disabled(didSave)
                .accessibilityIdentifier(AXID.reviewSaveButton)
            }
        }
        .navigationTitle("Review")
    }
}
