import SwiftUI
import SwiftData

struct CoverageEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminder
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var kind: CoverageKind = .returnWindow
    @State private var daysText = "30"
    @State private var intervalMonthsText = ""

    var body: some View {
        Form {
            Picker("Kind", selection: $kind) {
                ForEach(CoverageKind.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .accessibilityIdentifier(AXID.coverageKindPicker)
            if kind == .servicePlan {
                TextField("Service interval (months)", text: $intervalMonthsText).keyboardType(.numberPad)
            } else {
                TextField("Length (days)", text: $daysText).keyboardType(.numberPad)
            }
            Button("Add coverage") { add() }
                .accessibilityIdentifier(AXID.addCoverageButton)
        }
    }

    func add() {
        let start = Date.now
        let end: Date
        switch kind {
        case .returnWindow: end = Calendar.current.date(byAdding: .day, value: Int(daysText) ?? 30, to: start) ?? start
        case .servicePlan: end = .distantFuture
        default: end = Calendar.current.date(byAdding: .day, value: Int(daysText) ?? 365, to: start) ?? start
        }
        // Skip exact duplicates (same kind + end date) from double-taps.
        let day = Calendar.current.startOfDay(for: end)
        if (item.coverages ?? []).contains(where: { $0.kind == kind && Calendar.current.startOfDay(for: $0.endDate) == day }) {
            dismiss()
            return
        }
        let c = Coverage(kind: kind, start: start, end: end)
        if kind == .servicePlan { c.serviceIntervalMonths = Int(intervalMonthsText) }
        c.item = item
        item.coverages = (item.coverages ?? []) + [c]
        try? modelContext.save()
        Task { await reminder.rescheduleFromContext(modelContext) }
        dismiss()
    }
}
