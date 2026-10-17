import SwiftUI
import SwiftData

/// Ownwise Pro: choose which days before an end date to be reminded, and at what time.
struct ReminderSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminder
    @State private var prefs = ReminderPreferences.load()
    @State private var customTarget: LeadKind?
    @State private var customDaysText = ""

    private enum LeadKind { case returns, warranties }

    var body: some View {
        Form {
            Section {
                DatePicker("Remind me at", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier(AXID.reminderTimePicker)
            } footer: {
                Text("Applies to every reminder, including ones you set for a single item.")
            }

            Section {
                ForEach(rows(ReminderPreferences.returnLeadOptions, selected: prefs.returnLeads), id: \.self) { days in
                    leadRow(days, selected: $prefs.returnLeads)
                }
                addCustomButton(.returns)
            } header: {
                Text("Return windows")
            } footer: {
                Text("These are the defaults. Every item can use its own timing.")
            }

            Section {
                ForEach(rows(ReminderPreferences.warrantyLeadOptions, selected: prefs.warrantyLeads), id: \.self) { days in
                    leadRow(days, selected: $prefs.warrantyLeads)
                }
                addCustomButton(.warranties)
            } header: {
                Text("Warranties & insurance")
            } footer: {
                Text("Service plans remind you when service is due — change a single item if you want longer notice.")
            }

            Section {
                Button("Restore defaults") { prefs = .standard }
                    .disabled(prefs == .standard)
            }
        }
        .navigationTitle("Reminders")
        .alert("Remind me before", isPresented: Binding(get: { customTarget != nil }, set: { if !$0 { customTarget = nil } })) {
            TextField("Days", text: $customDaysText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier(AXID.customLeadDaysField)
            Button("Add") { addCustomLead() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter how many days before the end date (0–\(ReminderPreferences.maxLeadDays)).")
        }
        .onChange(of: prefs) { _, newValue in
            newValue.save()
            reminder.configure(isPro: true, saved: newValue)
            Task { await reminder.rescheduleFromContext(modelContext) }
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: { prefs.fireDate(on: .now) },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                prefs.hour = parts.hour ?? ReminderPreferences.standard.hour
                prefs.minute = parts.minute ?? 0
            }
        )
    }

    /// Presets plus any custom day counts the user added, longest lead first.
    private func rows(_ presets: [Int], selected: [Int]) -> [Int] {
        Set(presets + selected).sorted(by: >)
    }

    private func addCustomButton(_ kind: LeadKind) -> some View {
        Button {
            customDaysText = ""
            customTarget = kind
        } label: {
            Label("Add custom days…", systemImage: "plus")
        }
        .accessibilityIdentifier(kind == .returns ? AXID.addCustomReturnLeadButton : AXID.addCustomWarrantyLeadButton)
    }

    private func addCustomLead() {
        guard let target = customTarget,
              let days = ReminderPreferences.validLead(customDaysText) else { return }
        switch target {
        case .returns: prefs.returnLeads = ReminderPreferences.adding(days, to: prefs.returnLeads)
        case .warranties: prefs.warrantyLeads = ReminderPreferences.adding(days, to: prefs.warrantyLeads)
        }
        customTarget = nil
    }

    private func leadRow(_ days: Int, selected: Binding<[Int]>) -> some View {
        let isOn = selected.wrappedValue.contains(days)
        return Button {
            // Same ceiling rule as the per-item chips, in one tested place.
            selected.wrappedValue = ReminderPreferences.togglingGlobal(days, in: selected.wrappedValue)
        } label: {
            HStack {
                Text(ReminderPreferences.leadLabel(days)).foregroundStyle(Color.primary)
                Spacer()
                if isOn { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
