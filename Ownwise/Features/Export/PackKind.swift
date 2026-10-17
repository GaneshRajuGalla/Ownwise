import SwiftUI

/// Which document a pack is (E9).
///
/// The facts a store, a manufacturer or a buyer wants are the same — what it is, when it was bought,
/// how much cover is left, and the paper — so a resale pack is one document with a different title and
/// framing rather than a second code path that would drift from the first.
enum PackKind: String, Sendable, CaseIterable {
    /// For a store or a manufacturer, after something has gone wrong.
    case claim
    /// For a buyer, when the thing is being sold on: the same proof, framed as what they are getting.
    case handover

    var title: LocalizedStringKey {
        switch self {
        case .claim: "Claim Pack"
        case .handover: "Resale Pack"
        }
    }

    /// The first line of the file name, localised.
    var fileLabel: String {
        switch self {
        case .claim: String(localized: "Claim Pack", comment: "Export document name")
        case .handover: String(localized: "Resale Pack", comment: "Export document name")
        }
    }

    /// One line under the title saying what the document is for. A claim pack speaks for itself; a
    /// resale pack has to answer "what am I getting?".
    var purpose: LocalizedStringKey? {
        switch self {
        case .claim: nil
        case .handover:
            "Proof of purchase, serial number and the cover that is left — what a buyer asks for."
        }
    }
}
