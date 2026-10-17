import Testing
import Foundation
@testable import Ownwise

struct OrderedConcurrentMapTests {

    @Test("Results stay in input order even when tasks finish out of order")
    func preservesInputOrder() async {
        // Later elements sleep for less time, so they finish first and the naive
        // "append as they arrive" version would come back reversed.
        let input = Array(0..<20)
        let results = await orderedConcurrentMap(input) { value in
            try? await Task.sleep(for: .milliseconds((20 - value) * 2))
            return value * 2
        }
        #expect(results == input.map { $0 * 2 })
    }

    @Test("An empty input produces an empty result")
    func emptyInput() async {
        let results = await orderedConcurrentMap([Int]()) { $0 }
        #expect(results.isEmpty)
    }
}
