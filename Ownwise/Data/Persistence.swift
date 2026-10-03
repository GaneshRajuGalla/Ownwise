import SwiftData
import Foundation

enum Persistence {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema,
                                        isStoredInMemoryOnly: inMemory,
                                        cloudKitDatabase: .none)
        do { return try ModelContainer(for: schema, migrationPlan: MigrationPlan.self, configurations: config) }
        catch { fatalError("ModelContainer failed: \(error)") }
    }

    /// Seeds sample data for previews / `-seedSampleData` launch arg.
    @MainActor
    static func seedSampleData(into context: ModelContext) {
        let tv = Item(name: "55\" OLED TV")
        tv.brand = "LG"; tv.category = .electronics; tv.merchant = "Best Buy"
        tv.priceMinor = 9999900; tv.currencyCode = "USD"
        tv.purchaseDate = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .now
        tv.coverages = [Coverage(kind: .manufacturer, start: tv.purchaseDate, end: Calendar.current.date(byAdding: .year, value: 1, to: tv.purchaseDate) ?? .now)]

        let laptop = Item(name: "MacBook Air 13\"")
        laptop.brand = "Apple"; laptop.category = .computer; laptop.serialNumber = "C02ABCDE123"
        laptop.purchaseDate = Calendar.current.date(byAdding: .month, value: -6, to: .now) ?? .now
        laptop.coverages = [Coverage(kind: .returnWindow, start: laptop.purchaseDate, end: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now)]

        let washer = Item(name: "Washer")
        washer.brand = "Samsung"; washer.category = .appliance
        let svc = Coverage(kind: .servicePlan, start: washer.purchaseDate, end: .distantFuture)
        svc.serviceIntervalMonths = 3
        washer.coverages = [svc]

        for item in [tv, laptop, washer] { context.insert(item) }
        try? context.save()
    }
}
