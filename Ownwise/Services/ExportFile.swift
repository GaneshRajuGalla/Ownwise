import Foundation

/// A generated export on disk, ready to hand to the share sheet.
struct ExportFile: Identifiable, Sendable, Equatable {
    let url: URL
    var id: URL { url }
}
