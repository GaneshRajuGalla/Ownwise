import Testing
import Foundation
@testable import Ownwise

/// Phase 3's localisation and accessibility work is mostly compile-time — `LocalizedStringKey`
/// either accepts a literal or it does not. What can be pinned is the copy that reaches the user
/// and the links that used to be force-unwrapped.
struct LocalisationTests {

    @Test("Every enum label has copy, so no badge or notification can come out blank")
    func enumLabelsArePopulated() {
        for category in ItemCategory.allCases {
            #expect(!category.label.isEmpty)
        }
        for kind in CoverageKind.allCases {
            #expect(!kind.label.isEmpty)
        }
        for kind in AttachmentKind.allCases {
            #expect(!kind.label.isEmpty)
        }
    }

    @Test("Status badge keeps its short day form")
    func statusBadgeDays() {
        #expect(CoverageStatus.expiringSoon(days: 1).label == "1d left")
        #expect(CoverageStatus.expiringSoon(days: 30).label == "30d left")
        #expect(CoverageStatus.expired.label == "Expired")
        #expect(CoverageStatus.serviceDue.label == "Service due")
    }

    @Test("Every fixed link builds, so no force-unwrap can crash the app")
    func linksBuild() {
        #expect(Links.privacyPolicy?.scheme == "https")
        #expect(Links.privacyPolicy?.path.hasSuffix("privacy.html") == true)
        #expect(Links.supportPage?.scheme == "https")
        #expect(Links.supportEmail?.scheme == "mailto")
        #expect(Links.supportEmail?.path.contains("@") == true)
    }
}
