import SwiftUI
import SwiftData

/// Ownwise Pro: a one-off reminder for an item on a date and time the user picks.
struct CustomReminderEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminder
    @Environment(\.dismiss) private var dismiss
    let item: Item
    @State private var date: Date

    init(item: Item) {
        self.item = item
        let tomorrowNine = Calendar.current.date(byAdding: .day, value: 1, to: ReminderPreferences.load().fireDate(on: .now)) ?? .now
        _date = State(initialValue: item.customReminderDate.flatMap { $0 > .now ? $0 : nil } ?? tomorrowNine)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Remind me", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                } footer: {
                    Text("For anything not tied to a coverage date: a filter change, a claim follow-up, or checking a price drop.")
                }
                if item.customReminderDate != nil {
                    Section {
                        Button("Remove reminder", role: .destructive) { save(nil) }
                    }
                }
            }
            .navigationTitle("Custom reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(date) }
                        .accessibilityIdentifier(AXID.saveCustomReminderButton)
                }
            }
        }
    }

    private func save(_ newDate: Date?) {
        item.customReminderDate = newDate
        modelContext.saveOrReport()
        Task { await reminder.rescheduleFromContext(modelContext) }
        dismiss()
    }
}
