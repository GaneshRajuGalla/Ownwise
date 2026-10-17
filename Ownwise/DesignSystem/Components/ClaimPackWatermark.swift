import SwiftUI

/// The mark on a Claim Pack a free user generates: the real document, visibly unfinished, so the
/// value of the finished one is obvious before paying. Pro exports carry no mark.
struct ClaimPackWatermark: View {
    var body: some View {
        ZStack {
            Text("OWNWISE PREVIEW")
                .font(.system(size: 54, weight: .heavy))
                .foregroundStyle(Color.red.opacity(0.16))
                .rotationEffect(.degrees(-32))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack {
                Spacer()
                Text("Preview — unlock Ownwise Pro for the clean, print-ready copy.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.red.opacity(0.7))
                    .padding(.bottom, 12)
            }
        }
        .accessibilityHidden(true)
    }
}
