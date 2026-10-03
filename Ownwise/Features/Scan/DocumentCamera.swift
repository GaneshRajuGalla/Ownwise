import SwiftUI
import VisionKit

struct DocumentCamera: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    var onFail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, onFail: onFail) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        let onFail: () -> Void
        init(onScan: @escaping ([UIImage]) -> Void, onFail: @escaping () -> Void) {
            self.onScan = onScan; self.onFail = onFail
        }
        func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            onScan(images)
        }
        func documentCameraViewControllerDidCancel(_ vc: VNDocumentCameraViewController) { onFail() }
        func documentCameraViewController(_ vc: VNDocumentCameraViewController, didFailWithError error: Error) { onFail() }
    }
}
