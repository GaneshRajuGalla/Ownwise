import SwiftUI
import SwiftData

struct CoverageEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminder
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var kind: CoverageKind = .returnWindow
    @State private var start: Date
    @State private var lengthText = "30"
    @State private var leads: [Int]?

    init(item: Item) {
        self.item = item
        _start = State(initialValue: item.purchaseDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(CoverageKind.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .accessibilityIdentifier(AXID.coverageKindPicker)
                }
                Section {
                    DatePicker(kind == .servicePlan ? "Last serviced" : "Starts", selection: $start, displayedComponents: .date)
                    LabeledContent(Self.lengthLabel(kind)) {
                        TextField(Self.lengthLabel(kind), text: $lengthText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier(AXID.coverageLengthField)
                    }
                } footer: {
                    if let end = endDate {
                        Text(kind == .servicePlan
                             ? "Next service \(end.formatted(date: .long, time: .omitted))"
                             : "Ends \(end.formatted(date: .long, time: .omitted))")
                    } else {
                        Text("Enter a whole number.")
                    }
                }
                Section {
                    ReminderPresetPicker(kind: kind, leads: $leads)
                } header: {
                    Text("Remind me")
                } footer: {
                    Text(kind == .servicePlan
                         ? "Service reminders can fire before the due date, and on it."
                         : "Choose when we should alert you before this ends.")
                }
            }
            .navigationTitle("Add coverage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                        .disabled(endDate == nil)
                        .accessibilityIdentifier(AXID.saveCoverageButton)
                }
            }
            .onChange(of: kind) { _, newKind in
                lengthText = String(Self.defaultLength(newKind))
                start = newKind == .servicePlan ? .now : item.purchaseDate
                // Presets differ per kind, so a carried-over choice would mislead.
                leads = nil
            }
        }
    }

    private var length: Int? {
        guard let n = Int(lengthText.trimmingCharacters(in: .whitespaces)), n > 0 else { return nil }
        return n
    }

    private var endDate: Date? {
        length.map { Self.endDate(kind: kind, start: start, length: $0) }
    }

    // MARK: Rules (unit-tested)

    /// Return windows are counted in days; everything else in months.
    static func lengthLabel(_ kind: CoverageKind) -> LocalizedStringKey {
        switch kind {
        case .returnWindow: "Length (days)"
        case .servicePlan: "Service every (months)"
        default: "Length (months)"
        }
    }

    static func defaultLength(_ kind: CoverageKind) -> Int {
        switch kind {
        case .returnWindow: 30
        case .servicePlan: 6
        default: 12
        }
    }

    /// End of the coverage, or the next service date for service plans.
    static func endDate(kind: CoverageKind, start: Date, length: Int, calendar: Calendar = .current) -> Date {
        let component: Calendar.Component = kind == .returnWindow ? .day : .month
        return calendar.date(byAdding: component, value: length, to: start) ?? start
    }

    func add() {
        guard let length else { return }
        let end = kind == .servicePlan ? Date.distantFuture : Self.endDate(kind: kind, start: start, length: length)
        // Skip exact duplicates from double-taps. Service plans share `distantFuture` as their
        // end date, so they are compared by interval instead of date (C3).
        let duplicates = (item.coverages ?? []).contains { existing in
            guard existing.kind == kind else { return false }
            if kind == .servicePlan { return existing.serviceIntervalMonths == length }
            return Calendar.current.startOfDay(for: existing.endDate) == Calendar.current.startOfDay(for: end)
        }
        if duplicates {
            dismiss()
            return
        }
        let c = Coverage(kind: kind, start: start, end: end)
        c.reminderLeadDays = leads
        if kind == .servicePlan {
            c.serviceIntervalMonths = length
            c.lastServiceDate = start
        }
        c.item = item
        item.coverages = (item.coverages ?? []) + [c]
        modelContext.saveOrReport()
        Task { await reminder.rescheduleFromContext(modelContext) }
        dismiss()
    }
}
