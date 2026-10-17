import Testing
import Foundation
import SwiftData
@testable import Ownwise

/// The widget's snapshot: what it contains, in what order, and what happens when there is no App
/// Group to put it in (E2).
@MainActor
struct SnapshotTests {

    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func date(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: now)!
    }

    private func tempSnapshot() throws -> SharedSnapshot {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SnapshotTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return SharedSnapshot(directory: directory)
    }

    @Test("Ordered by what runs out first")
    func ordering() {
        let kettle = Item(name: "Kettle")
        kettle.coverages = [Coverage(kind: .manufacturer, start: date(-300), end: date(30))]
        let tv = Item(name: "TV")
        tv.coverages = [Coverage(kind: .manufacturer, start: date(-300), end: date(5))]

        let value = SnapshotBuilder.value(from: [kettle, tv], now: now)

        #expect(value.entries.map(\.name) == ["TV", "Kettle"])
        #expect(value.entries.first?.endDate == date(5))
        #expect(value.entries.first?.kind == CoverageKind.manufacturer.label)
        #expect(value.generatedAt == now)
    }

    @Test("A service plan is shown as its next service date, not its open-ended end")
    func servicePlan() {
        let washer = Item(name: "Washer")
        let service = CoverageBuilder.make(kind: .servicePlan, start: date(-200), length: 6)
        washer.coverages = [service]

        let value = SnapshotBuilder.value(from: [washer], now: now)

        #expect(value.entries.count == 1)
        #expect(value.entries.first?.endDate == service.nextServiceDate)
        #expect(value.entries.first?.endDate != Date.distantFuture)
    }

    @Test("Cover that expired long ago is left out rather than shown forever")
    func expiredIsNoise() {
        let kettle = Item(name: "Kettle")
        kettle.coverages = [Coverage(kind: .manufacturer, start: date(-500), end: date(-30))]

        #expect(SnapshotBuilder.value(from: [kettle], now: now).entries.isEmpty)
    }

    @Test("A widget shows five at most")
    func capped() {
        let items = (0..<8).map { index -> Item in
            let item = Item(name: "Item \(index)")
            item.coverages = [Coverage(kind: .manufacturer, start: date(-300), end: date(index + 1))]
            return item
        }

        let value = SnapshotBuilder.value(from: items, now: now)

        #expect(value.entries.count == SharedSnapshot.maxEntries)
        #expect(value.entries.first?.name == "Item 0")
    }

    @Test("It round-trips through the file, and is inert without an App Group")
    func roundTrip() throws {
        let snapshot = try tempSnapshot()
        #expect(snapshot.isAvailable)
        #expect(snapshot.read() == nil)

        let value = SharedSnapshot.Value(generatedAt: now,
                                         entries: [SharedSnapshot.Entry(id: UUID(), itemID: UUID(),
                                                                        name: "Kettle", kind: "Warranty",
                                                                        endDate: date(9))])
        snapshot.write(value)
        #expect(snapshot.read() == value)

        let inert = SharedSnapshot(directory: nil)
        #expect(inert.isAvailable == false)
        #expect(inert.read() == nil)
        inert.write(value)          // must be a no-op, not a crash
    }

    @Test("Refreshing writes what the builder made")
    func refreshWrites() throws {
        let snapshot = try tempSnapshot()
        let kettle = Item(name: "Kettle")
        kettle.coverages = [Coverage(kind: .manufacturer, start: date(-300), end: date(9))]

        SnapshotBuilder.refresh(items: [kettle], into: snapshot, now: now)

        #expect(snapshot.read()?.entries.map(\.name) == ["Kettle"])
    }
}
