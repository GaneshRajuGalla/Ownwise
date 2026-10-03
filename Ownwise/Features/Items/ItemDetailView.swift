import SwiftUI
import SwiftData
import UIKit

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderScheduler.self) private var reminder
    let item: Item

    @State private var showEdit = false
    @State private var showCoverage = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                hero
                coverageSection
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
        .confirmationDialog("Delete item?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { delete() }.accessibilityIdentifier(AXID.deleteItemButton)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) { showDelete = true } label: { Image(systemName: "trash") }
                    .accessibilityIdentifier("delete_item_trash")
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
                if let status = (item.coverages ?? []).map({ coverageStatus(of: $0, now: .now) }).first {
                    StatusBadge(status: status)
                }
            }
        }
    }

    var coverageSection: some View {
        SectionCard(title: "Coverage timeline") {
            ForEach((item.coverages ?? []).sorted(by: { $0.startDate < $1.startDate }), id: \.id) { c in
                HStack {
                    Image(systemName: Palette.icon(for: coverageStatus(of: c, now: .now)))
                        .foregroundStyle(Palette.color(for: coverageStatus(of: c, now: .now)))
                    VStack(alignment: .leading) {
                        Text(c.kind.label).font(.body)
                        Text(c.endDate, format: .dateTime.day().month().year()).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: coverageStatus(of: c, now: .now))
                }
                .padding(.vertical, 2)
            }
            Button("Add coverage") { showCoverage = true }
                .accessibilityIdentifier(AXID.addCoverageButton)
        }
    }

    var actions: some View {
        GlassEffectContainer(spacing: DS.Space.m) {
            HStack(spacing: DS.Space.m) {
                Button {
                    UIPasteboard.general.string = item.serialNumber
                    copied = true
                } label: { Label("Copy serial", systemImage: "doc.on.doc").labelStyle(.iconOnly) }
                .buttonStyle(.glass)
                .accessibilityLabel("Copy serial")
                Button { call() } label: { Label("Call support", systemImage: "phone").labelStyle(.iconOnly) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Call support")
                Button { showCoverage = true } label: { Label("Add coverage", systemImage: "plus.circle").labelStyle(.iconOnly) }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Add coverage")
                    .accessibilityIdentifier(AXID.addCoverageButton)
            }
            .font(.title3)
        }
    }

    var attachmentsSection: some View {
        SectionCard(title: "Attachments") {
            if (item.attachments ?? []).isEmpty {
                Text("No attachments").foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(item.attachments ?? [], id: \.id) { att in
                    HStack {
                        Image(systemName: "doc")
                        Text(att.contentType).font(.footnote)
                    }
                }
            }
        }
    }

    func call() {
        guard !item.supportPhone.isEmpty, let url = URL(string: "tel:\(item.supportPhone)") else { return }
        UIApplication.shared.open(url)
    }

    func delete() {
        modelContext.delete(item)
        try? modelContext.save()
        Task { await reminder.rescheduleFromContext(modelContext) }
    }
}
