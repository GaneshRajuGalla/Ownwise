import Testing
import Foundation
import SwiftData
@testable import Ownwise

/// Acting on a reminder without opening the app (B4).
@MainActor
struct NoticeActionsTests {

    private func container() -> ModelContainer {
        Persistence.makeContainer(inMemory: true)
    }

    @Test("Mark serviced from the notification records the service")
    func markServiced() throws {
        let container = container()
        let context = container.mainContext
        let washer = Item(name: "Washer")
        let service = CoverageBuilder.make(kind: .servicePlan, start: .now, length: 6)
        washer.coverages = [service]
        context.insert(washer)
        context.saveOrReport()

        let handled = NoticeActions.handle(actionIdentifier: Notices.markServicedAction,
                                           coverageID: service.id, in: container)

        #expect(handled)
        // The service date moves, which is what "serviced" means — and what the next reminder and the
        // widget's snapshot are built from.
        #expect(service.lastServiceDate != nil)
        #expect(service.nextServiceDate ?? .distantPast > .now)
    }

    @Test("An action we do not know, or a coverage that is gone, changes nothing")
    func unknownActionOrCoverage() {
        let container = container()

        #expect(NoticeActions.handle(actionIdentifier: "somethingElse",
                                     coverageID: UUID(), in: container) == false)
        #expect(NoticeActions.handle(actionIdentifier: Notices.markServicedAction,
                                     coverageID: UUID(), in: container) == false)
    }

    @Test("The payload the reminder carries is read back exactly")
    func payloadRoundTrip() {
        let id = UUID()

        #expect(Notices.coverageID(from: [Notices.coverageKey: id.uuidString]) == id)
        #expect(Notices.coverageID(from: [Notices.coverageKey: "not-a-uuid"]) == nil)
        #expect(Notices.coverageID(from: [:]) == nil)
    }
}
