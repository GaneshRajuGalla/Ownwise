import SwiftUI
import SwiftData

/// Change when one coverage reminds you.
///
/// Bulk apply ("and my other warranties too") lives here rather than in the add
/// flow, so a user with 40 items never has to repeat the same choice 40 times.
struct CoverageReminderEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ReminderScheduler.self) private var reminder
    let coverage: Coverage

    @State private var leads: [Int]?
    @State private var appliedCount: Int?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ReminderPresetPicker(kind: coverage.kind, leads: $leads)
                } header: {
                    Text(coverage.kind.label)
                } footer: {
                    Text(endText)
                }

                Section {
                    Button(applyTitle) { applyToAll() }
                        .disabled(leads == nil)
                        .accessibilityIdentifier(AXID.applyReminderToAllButton)
                } footer: {
                    Text("Uses the same timing on your other \(coverage.kind.label.lowercased()) coverages.")
                }
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear { leads = coverage.reminderLeadDays }
        }
    }

    private var endText: String {
        if coverage.kind == .servicePlan, let next = coverage.nextServiceDate {
            return String(localized: "Next service \(next.formatted(date: .long, time: .omitted)).")
        }
        return String(localized: "Coverage ends \(coverage.endDate.formatted(date: .long, time: .omitted)).")
    }

    private var applyTitle: LocalizedStringKey {
        if let appliedCount { "Applied to \(appliedCount) coverages" }
        else { "Use this for every \(coverage.kind.label.lowercased())" }
    }

    private func save() {
        coverage.reminderLeadDays = leads
        modelContext.saveOrReport()
        Task { await reminder.rescheduleFromContext(modelContext) }
        dismiss()
    }

    /// Copies this choice onto every coverage of the same kind, so it applies
    /// to existing items too — not just the next one that gets added.
    private func applyToAll() {
        guard let leads else { return }
        let items = (try? modelContext.fetch(FetchDescriptor<Item>())) ?? []
        var changed = 0
        for item in items {
            for c in item.coverages ?? [] where c.kind == coverage.kind {
                guard c.id != coverage.id else { continue }
                c.reminderLeadDays = leads
                changed += 1
            }
        }
        coverage.reminderLeadDays = leads
        modelContext.saveOrReport()
        Task { await reminder.rescheduleFromContext(modelContext) }
        appliedCount = changed
    }
}
