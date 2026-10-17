import SwiftUI
import SwiftData

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminder
    @State var model: ReviewModel
    @State private var didSave = false
    var onSaved: () -> Void

    var body: some View {
        Form {
            Section("Item") {
                TextField("Name", text: $model.name).accessibilityIdentifier(AXID.reviewNameField)
                TextField("Merchant", text: $model.merchant).accessibilityIdentifier(AXID.reviewMerchantField)
                TextField("Brand", text: $model.brand).accessibilityIdentifier(AXID.reviewBrandField)
                TextField("Model number", text: $model.modelNumber).accessibilityIdentifier(AXID.reviewModelField)
                TextField("Serial number", text: $model.serialNumber).accessibilityIdentifier(AXID.reviewSerialField)
                Picker("Category", selection: $model.category) {
                    ForEach(ItemCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .accessibilityIdentifier(AXID.itemCategoryPicker)
                DatePicker("Purchased", selection: $model.purchaseDate, displayedComponents: .date)
                    .accessibilityIdentifier(AXID.reviewDateField)
            }
            Section("Price") {
                TextField("Total", text: $model.totalText).keyboardType(.decimalPad).accessibilityIdentifier(AXID.reviewTotalField)
                TextField("Currency code", text: $model.currencyCode).accessibilityIdentifier(AXID.reviewCurrencyField)
                TextField("Order number", text: $model.orderNumber).accessibilityIdentifier(AXID.reviewOrderField)
            }
            Section("Coverage") {
                TextField("Warranty (months)", text: $model.warrantyMonthsText)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier(AXID.reviewWarrantyMonthsField)
                TextField("Return window (days)", text: $model.returnDaysText)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier(AXID.reviewReturnDaysField)
            }
            if model.returnDays > 0 || model.warrantyMonths > 0 {
                Section {
                    if model.returnDays > 0 {
                        reminderRow("Return window", kind: .returnWindow, leads: $model.returnLeads)
                    }
                    if model.warrantyMonths > 0 {
                        reminderRow("Warranty", kind: .manufacturer, leads: $model.warrantyLeads)
                    }
                } header: {
                    Text("Remind me")
                } footer: {
                    Text("Choose when we should alert you. You can change this later from the item.")
                }
                .accessibilityIdentifier(AXID.itemReminderSection)
            }
            if !model.fieldsFromAI.isEmpty {
                Section {
                    Label("Some fields were filled in by on-device AI. Please check them before saving.", systemImage: "sparkles")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Save item") {
                    guard !didSave else { return }
                    didSave = true
                    model.save(into: modelContext)
                    // Scanned items used to wait for the next launch before their
                    // reminders existed; schedule them the moment they're saved.
                    Task { await reminder.rescheduleFromContext(modelContext) }
                    onSaved()
                }
                .disabled(didSave)
                .accessibilityIdentifier(AXID.reviewSaveButton)
            }
        }
        .navigationTitle("Review")
    }

    /// A titled chip row for one coverage kind.
    private func reminderRow(_ title: LocalizedStringKey, kind: CoverageKind, leads: Binding<[Int]?>) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(title).font(.subheadline.weight(.semibold))
            ReminderPresetPicker(kind: kind, leads: leads)
        }
        .padding(.vertical, DS.Space.xs)
    }
}
