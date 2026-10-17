import SwiftUI

/// Chips for choosing when to be reminded about one coverage.
///
/// One design rule: the chips are **pre-selected to the smart default**, so a
/// user who ignores this section gets exactly the old behaviour. Choosing a
/// preset is free; typing your own day count is Ownwise Pro.
struct ReminderPresetPicker: View {
    let kind: CoverageKind
    /// `nil` means "not chosen" — fall back to the default shown to the user.
    @Binding var leads: [Int]?

    @Environment(ReminderScheduler.self) private var reminder
    @Environment(StoreManager.self) private var store

    @State private var showPaywall = false
    @State private var isAddingCustom = false
    @State private var customText = ""

    /// Chips shown lit: the user's pick, else what would fire by default.
    private var selected: [Int] { ReminderPreferences.normalizedLeads(leads ?? defaultLeads) }
    private var defaultLeads: [Int] { reminder.preferences.leads(for: kind) }
    private var usingDefault: Bool { leads == nil }
    /// Presets, plus any custom value already in play, longest lead first.
    private var options: [Int] { Set(ReminderPreferences.presets(for: kind) + selected).sorted(by: >) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: DS.Space.s)], spacing: DS.Space.s) {
                ForEach(options, id: \.self) { chip($0) }
                customChip
            }
            HStack(alignment: .firstTextBaseline) {
                Text(footerText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Space.s)
                if !usingDefault {
                    Button("Use default") { leads = nil }
                        .font(.footnote)
                        .accessibilityIdentifier(AXID.resetReminderLeadsButton)
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Remind me before", isPresented: $isAddingCustom) {
            TextField("Days", text: $customText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier(AXID.customLeadDaysField)
            Button("Add") { addCustom() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter how many days before (0–\(ReminderPreferences.maxLeadDays)).")
        }
    }

    private var footerText: String {
        usingDefault
            ? String(localized: "Smart default: \(ReminderPreferences.presetPhrase(defaultLeads)), at \(fireTime).")
            : String(localized: "We'll remind you \(ReminderPreferences.presetPhrase(selected)), at \(fireTime).")
    }

    /// The global time of day still applies to a single item's days choice, so
    /// name it here too — otherwise this screen and Settings disagree.
    private var fireTime: String {
        reminder.preferences.fireDate(on: .now).formatted(date: .omitted, time: .shortened)
    }

    // MARK: Chips

    private func chip(_ day: Int) -> some View {
        let isOn = selected.contains(day)
        return Button { toggle(day) } label: {
            chipLabel(ReminderPreferences.chipLabel(day), isOn: isOn, systemImage: isOn ? "checkmark" : nil)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(AXID.reminderPresetPrefix)\(day)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var customChip: some View {
        Button {
            if store.isPro { customText = ""; isAddingCustom = true } else { showPaywall = true }
        } label: {
            chipLabel(String(localized: "Custom…"), isOn: false, systemImage: store.isPro ? "plus" : "lock.fill", isLocked: !store.isPro)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AXID.customReminderLeadButton)
    }

    private func chipLabel(_ text: String, isOn: Bool, systemImage: String?, isLocked: Bool = false) -> some View {
        HStack(spacing: DS.Space.xs) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.bold())
            }
            Text(text)
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, DS.Space.m)
        .padding(.vertical, DS.Space.s)
        .frame(maxWidth: .infinity)
        .foregroundStyle(isOn ? Color.indigo : (isLocked ? Color.secondary : Color.primary))
        .background(isOn ? Color.indigo.opacity(0.15) : Color(.secondarySystemGroupedBackground), in: .capsule)
        .overlay(Capsule().strokeBorder(isOn ? Color.indigo.opacity(0.6) : Color(.separator), lineWidth: 1))
    }

    // MARK: Rules

    private func toggle(_ day: Int) {
        leads = ReminderPreferences.toggling(day, in: selected)
    }

    /// Pro only: "whatever I have, plus 45 days" is usually what people mean.
    private func addCustom() {
        guard let days = ReminderPreferences.validLead(customText) else { return }
        leads = ReminderPreferences.adding(days, to: selected)
    }
}
