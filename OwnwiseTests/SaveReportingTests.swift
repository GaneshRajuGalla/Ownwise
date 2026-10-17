import Testing
import SwiftData
@testable import Ownwise

@MainActor
struct SaveReportingTests {

    @Test("A save that lands reports success, so a caller is never told a failed write worked")
    func reportsSuccessfulSave() throws {
        let container = Persistence.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(Item(name: "Kettle"))

        let saved = context.saveOrReport()

        #expect(saved)
        let count = try context.fetch(FetchDescriptor<Item>()).count
        #expect(count == 1)
    }
}
