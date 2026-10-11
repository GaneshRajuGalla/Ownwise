import SwiftUI
import UIKit

/// System share sheet for a file, presented straight from an export action.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.view.accessibilityIdentifier = AXID.shareSheet
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
