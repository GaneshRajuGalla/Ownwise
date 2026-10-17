import Foundation

/// Runs `transform` for every element concurrently, then returns the results in input order.
/// A task group yields results as they finish, which would reorder the pages of one receipt;
/// the index carried by each child result puts them back where they came from.
nonisolated func orderedConcurrentMap<Element: Sendable, Result: Sendable>(
    _ elements: [Element],
    _ transform: @escaping @Sendable (Element) async -> Result
) async -> [Result] {
    await withTaskGroup(of: (index: Int, value: Result).self) { group in
        for (index, element) in elements.enumerated() {
            group.addTask { (index, await transform(element)) }
        }
        var byIndex = [Result?](repeating: nil, count: elements.count)
        for await child in group { byIndex[child.index] = child.value }
        // Every added task yields exactly once, so nothing is missing here.
        var ordered: [Result] = []
        ordered.reserveCapacity(elements.count)
        for index in elements.indices {
            guard let value = byIndex[index] else { continue }
            ordered.append(value)
        }
        return ordered
    }
}
