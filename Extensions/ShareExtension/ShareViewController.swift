import UIKit
import UniformTypeIdentifiers

/// The share extension's entry point (E1).
///
/// It does one thing: read what the user shared, and hand it to `SharedInbox`, which writes it into
/// the App Group container for the app to import on its next launch (or foreground). It never opens
/// the app's database — one writer keeps the store safe.
///
/// **This file is intentionally not part of any target yet.** An extension needs its own bundle id,
/// its own provisioning and an App Group, so it is created in Xcode; the app side is meanwhile built,
/// tested and inert. See `docs/share-extension.md` for the exact steps. When the target is created,
/// add `Ownwise/Services/Import/SharedInbox.swift` to it as well — the two halves have to agree on the
/// manifest format, so they share the file rather than each writing their own version of it.
final class ShareViewController: UIViewController {

    /// Read in this order, so a provider that offers both (Safari offers the page URL *and* a preview
    /// image) becomes the link and its text rather than a screenshot.
    private static let handledTypes: [UTType] = [.plainText, .url, .image, .pdf, .data]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task { await handle() }
    }

    private func handle() async {
        var entry = SharedInbox.Entry()
        var files: [(name: String, data: Data)] = []

        for item in (extensionContext?.inputItems as? [NSExtensionItem]) ?? [] {
            if entry.text.isEmpty, let text = item.attributedContentText?.string {
                entry.text = text
            }
            for provider in item.attachments ?? [] {
                await collect(from: provider, into: &entry, files: &files)
            }
        }

        if entry.title.isEmpty {
            entry.title = entry.url.isEmpty ? "Shared item" : entry.url
        }
        // An empty share must still dismiss, and must not leave a stray entry behind.
        if !files.isEmpty || !entry.text.isEmpty || !entry.url.isEmpty {
            do {
                try SharedInbox.default.enqueue(entry, files: files)
            } catch {
                // Never block the host app because our own copy failed; the sheet closes and the
                // user can share again.
            }
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// One attachment: text and links are kept on the entry, images and files become payload files.
    /// Only the first readable representation of a provider is used.
    private func collect(from provider: NSItemProvider, into entry: inout SharedInbox.Entry,
                         files: inout [(name: String, data: Data)]) async {
        for type in Self.handledTypes where provider.hasItemConformingToTypeIdentifier(type.identifier) {
            guard let data = await Self.data(from: provider, type: type) else { continue }

            if type.conforms(to: .plainText) {
                if entry.text.isEmpty { entry.text = String(data: data, encoding: .utf8) ?? "" }
            } else if type.conforms(to: .url) {
                if entry.url.isEmpty { entry.url = String(data: data, encoding: .utf8) ?? "" }
            } else {
                files.append((Self.fileName(for: provider, type: type, index: files.count), data))
            }
            if entry.title.isEmpty, let name = provider.suggestedName {
                entry.title = name
            }
            return
        }
    }

    private static func data(from provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func fileName(for provider: NSItemProvider, type: UTType, index: Int) -> String {
        if let name = provider.suggestedName, !name.isEmpty { return name }
        return "shared-\(index).\(type.preferredFilenameExtension ?? "dat")"
    }
}
