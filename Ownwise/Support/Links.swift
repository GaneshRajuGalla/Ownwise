import Foundation

/// The app's fixed external links. Optional rather than force-unwrapped: a link that cannot be
/// built is simply not offered, instead of taking the app down with it.
nonisolated enum Links {
    static var privacyPolicy: URL? {
        URL(string: "https://ganeshrajugalla.github.io/Ownwise/privacy.html")
    }

    static var supportPage: URL? {
        URL(string: "https://ganeshrajugalla.github.io/Ownwise/support.html")
    }

    static var supportEmail: URL? {
        URL(string: "mailto:ganeshraju14014@gmail.com")
    }
}
