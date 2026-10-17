import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ReminderScheduler.self) private var reminder
    @Environment(StoreManager.self) private var store
    let item: Item

    @State private var showEdit = false
    @State private var showCoverage = false
    @State private var copied = false
    @State private var shareFile: ExportFile?
    @State private var showPaywall = false
    @State private var exportError: String?
    @State private var showCustomReminder = false
    @State private var editingCoverage: Coverage?
    @State private var photoSelection: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                hero
                detailsSection
                coverageSection
                reminderSection
                actions
                attachmentsSection
                if !item.notes.isEmpty {
                    SectionCard(title: "Notes") { Text(item.notes).font(.body) }
                }
            }
            .padding(DS.Space.l)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEdit = true } label: { Image(systemName: "pencil") }
                    .accessibilityIdentifier(AXID.editItemButton)
            }
        }
        .sheet(isPresented: $showEdit) { EditItemView(item: item) { showEdit = false } }
        .sheet(isPresented: $showCoverage) { CoverageEditor(item: item) }
        .sheet(item: $shareFile) { file in
            ShareSheet(url: file.url)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showCustomReminder) { CustomReminderEditor(item: item) }
        .sheet(item: $editingCoverage) { coverage in
            CoverageReminderEditor(coverage: coverage)
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .confirmationDialog("Delete item?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { delete() }.accessibilityIdentifier(AXID.deleteItemButton)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) { showDelete = true } label: { Image(systemName: "trash") }
                    .accessibilityIdentifier(AXID.deleteItemTrashButton)
            }
        }
    }

    @State private var showDelete = false

    var hero: some View {
        SectionCard {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.title2.bold())
                    if !item.brand.isEmpty { Text(item.brand).foregroundStyle(.secondary) }
                    if !item.merchant.isEmpty { Text(item.merchant).foregroundStyle(.secondary) }
                    Text(item.purchaseDate, format: .dateTime.day().month().year()).font(.footnote).foregroundStyle(.tertiary)
                }
                Spacer()
                if let status = overallStatus(of: item.coverages ?? [], now: .now) {
                    StatusBadge(status: status)
                }
            }
        }
    }

    /// The facts a store or manufacturer asks for during a claim.
    @ViewBuilder
    var detailsSection: some View {
        let rows: [(LocalizedStringKey, String)] = [
            ("Price", item.priceMinor.map { Money.formatted($0, currencyCode: item.currencyCode) } ?? ""),
            ("Serial number", item.serialNumber),
            ("Model number", item.modelNumber),
            ("Order number", item.orderNumber),
            ("Tax / VAT number", item.taxID),
            ("Support phone", item.supportPhone),
        ].filter { !$0.1.isEmpty }
        if !rows.isEmpty {
            SectionCard(title: "Details") {
                ForEach(rows.indices, id: \.self) { i in
                    LabeledContent(rows[i].0) {
                        Text(rows[i].1).textSelection(.enabled)
                    }
                    .font(.body)
                }
            }
        }
    }

    var coverageSection: some View {
        SectionCard(title: "Coverage timeline") {
            if (item.coverages ?? []).isEmpty {
                Text("No coverage yet. Add a return window or warranty to get reminders.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach((item.coverages ?? []).sorted(by: { $0.startDate < $1.startDate }), id: \.id) { c in
                HStack {
                    Image(systemName: Palette.icon(for: coverageStatus(of: c, now: .now)))
                        .foregroundStyle(Palette.color(for: coverageStatus(of: c, now: .now)))
                    VStack(alignment: .leading) {
                        Text(c.kind.label).font(.body)
                        Text(coverageDateText(c)).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: coverageStatus(of: c, now: .now))
                }
                .padding(.vertical, 2)
                .contentShape(.rect)
                .contextMenu {
                    if c.kind == .servicePlan && c.serviceIntervalMonths != nil {
                        Button("Mark as serviced today", systemImage: "checkmark.circle") { markServiced(c) }
                    }
                    Button("Delete coverage", systemImage: "trash", role: .destructive) { deleteCoverage(c) }
                }
                if c.kind == .servicePlan, coverageStatus(of: c, now: .now) == .serviceDue {
                    Button("Mark as serviced today") { markServiced(c) }
                        .font(.subheadline)
                        .accessibilityIdentifier(AXID.markServicedButton)
                }
            }
            Button("Add coverage") { showCoverage = true }
                .accessibilityIdentifier(AXID.addCoverageButton)
        }
    }

    var reminderSection: some View {
        SectionCard(title: "Reminders") {
            if coverageReminders.isEmpty {
                Text("Coverage reminders are automatic as soon as you add a return window or warranty.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(coverageReminders, id: \.id) { c in
                Button { editingCoverage = c } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.kind.label).font(.body).foregroundStyle(Color.primary)
                            Text(coverageReminderText(c)).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .flipsForRightToLeftLayoutDirection(true)
                    }
                }
                .accessibilityIdentifier("\(AXID.editCoverageReminderPrefix)\(c.id.uuidString)")
            }

            Divider()

            if let date = item.customReminderDate, date > .now, store.isPro {
                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "bell")
                    .font(.body)
                Button("Change reminder") { showCustomReminder = true }
                    .accessibilityIdentifier(AXID.itemCustomReminderButton)
            } else {
                Text("Need an alert on your own date, outside any coverage?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Add a custom reminder") {
                    if store.isPro { showCustomReminder = true } else { showPaywall = true }
                }
                .accessibilityIdentifier(AXID.itemCustomReminderButton)
            }
        }
    }

    /// Every coverage's schedule, soonest end first.
    private var coverageReminders: [Coverage] {
        (item.coverages ?? []).sorted { $0.endDate < $1.endDate }
    }

    /// What will actually fire, resolved through the scheduler (so a Pro user's
    /// global choice shows up here too, not just the built-in defaults).
    func coverageReminderText(_ c: Coverage) -> String {
        ReminderPreferences.presetPhrase(reminder.leads(for: c))
    }

    var actions: some View {
        GlassEffectContainer(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.m) {
                if !item.serialNumber.isEmpty {
                    Button {
                        UIPasteboard.general.string = item.serialNumber
                        copied.toggle()
                    } label: { Label("Copy serial", systemImage: "doc.on.doc").labelStyle(.iconOnly) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Copy serial")
                    .sensoryFeedback(.success, trigger: copied)
                }
                if !item.supportPhone.isEmpty {
                    Button { call() } label: { Label("Call support", systemImage: "phone").labelStyle(.iconOnly) }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Call support")
                }
                Button { showCoverage = true } label: { Label("Add coverage", systemImage: "plus.circle").labelStyle(.iconOnly) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Add coverage")
                    .accessibilityIdentifier(AXID.addCoverageButton)
                Button { claimPack() } label: { Label("Claim Pack", systemImage: "doc.richtext").labelStyle(.iconOnly) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Claim Pack")
                    .accessibilityIdentifier(AXID.itemClaimPackButton)
            }
            .font(.title3)
        }
    }

    var attachmentsSection: some View {
        SectionCard(title: "Attachments") {
            if (item.attachments ?? []).isEmpty {
                Text("Add a photo of the receipt or warranty card. It's included in the Claim Pack.")
                    .foregroundStyle(.secondary).font(.subheadline)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.m) {
                        ForEach(item.attachments ?? [], id: \.id) { att in
                            if let data = att.fileData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 128)
                                    .clipShape(.rect(cornerRadius: DS.Radius.chip))
                                    .accessibilityLabel((AttachmentKind(rawValue: att.kindRaw) ?? .photo).label)
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) { deleteAttachment(att) }
                                    }
                            } else {
                                Label((AttachmentKind(rawValue: att.kindRaw) ?? .photo).label, systemImage: "doc")
                                    .font(.footnote)
                            }
                        }
                    }
                }
            }
            PhotosPicker(selection: $photoSelection, matching: .images) {
                Label("Add photo", systemImage: "photo.badge.plus")
            }
            .accessibilityIdentifier(AXID.addAttachmentButton)
            .onChange(of: photoSelection) { _, selection in
                guard let selection else { return }
                Task { await addPhoto(selection) }
            }
        }
    }

    func coverageDateText(_ c: Coverage) -> String {
        if c.kind == .servicePlan {
            guard let next = c.nextServiceDate else { return String(localized: "No service interval set") }
            return String(localized: "Next service \(next.formatted(date: .abbreviated, time: .omitted))")
        }
        return String(localized: "Ends \(c.endDate.formatted(date: .abbreviated, time: .omitted))")
    }

    /// Starts the next service interval from today, so reminders keep recurring.
    /// The mutation itself belongs to `LibraryActions` (H3); rescheduling is this screen's job.
    func markServiced(_ c: Coverage) {
        LibraryActions.markServiced(c, in: modelContext)
        Task { await reminder.rescheduleFromContext(modelContext) }
    }

    func deleteCoverage(_ c: Coverage) {
        LibraryActions.delete(c, of: item, in: modelContext)
        Task { await reminder.rescheduleFromContext(modelContext) }
    }

    func deleteAttachment(_ att: Attachment) {
        LibraryActions.delete(att, of: item, in: modelContext)
    }

    func addPhoto(_ selection: PhotosPickerItem) async {
        defer { photoSelection = nil }
        guard let data = try? await selection.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.7) else { return }
        LibraryActions.addAttachment(data: jpeg, kind: .photo, contentType: "public.jpeg",
                                     to: item, in: modelContext)
    }

    func call() {
        let digits = item.supportPhone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel:\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    func claimPack() {
        // Free users get the same document, watermarked, so the value is visible before paying.
        do { shareFile = try ExportService().claimPackFile(for: item, watermark: !store.isPro) }
        catch { exportError = error.localizedDescription }
    }

    func delete() {
        // Leave the screen first so nothing reads the deleted model.
        dismiss()
        LibraryActions.delete(item, in: modelContext)
        Task { await reminder.rescheduleFromContext(modelContext) }
    }
}
