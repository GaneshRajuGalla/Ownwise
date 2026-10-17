import Foundation
import SwiftData
import OSLog

private let saveLog = Logger(subsystem: "com.ownwise.Ownwise", category: "Persistence")

extension ModelContext {
    /// Saves, or reports the failure instead of swallowing it. SwiftData has no central error
    /// channel, so the call site is logged; a write that did not land must never look successful.
    @discardableResult
    func saveOrReport(file: StaticString = #fileID, line: UInt = #line) -> Bool {
        do {
            try save()
            return true
        } catch {
            saveLog.error("save() failed at \(file, privacy: .public):\(Int(line), privacy: .public) — \(error, privacy: .public)")
            return false
        }
    }
}
