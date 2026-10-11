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
                Text("Applies to all coverage reminders.")
            }

            Section {
                ForEach(rows(ReminderPreferences.returnLeadOptions, selected: prefs.returnLeads), id: \.self) { days in
                    leadRow(days, selected: $prefs.returnLeads)
                }
                addCustomButton(.returns)
            } header: {
                Text("Return windows")
            }

            Section {
                ForEach(rows(ReminderPreferences.warrantyLeadOptions, selected: prefs.warrantyLeads), id: \.self) { days in
                    leadRow(days, selected: $prefs.warrantyLeads)
                }
                addCustomButton(.warranties)
            } header: {
                Text("Warranties & insurance")
            } footer: {
                Text("Service plans remind you on the day service is due. Add a one-off reminder from any item.")
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
        case .returns: if !prefs.returnLeads.contains(days) { prefs.returnLeads.append(days) }
        case .warranties: if !prefs.warrantyLeads.contains(days) { prefs.warrantyLeads.append(days) }
        }
        customTarget = nil
    }

    private func leadRow(_ days: Int, selected: Binding<[Int]>) -> some View {
        let isOn = selected.wrappedValue.contains(days)
        return Button {
            if isOn { selected.wrappedValue.removeAll { $0 == days } } else { selected.wrappedValue.append(days) }
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
