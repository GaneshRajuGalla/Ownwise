import SwiftUI

/// Marks a row or control that needs Ownwise Pro. Icon plus text, so the
/// meaning never rests on colour alone.
struct ProBadge: View {
    var body: some View {
        Label("Pro", systemImage: "lock.fill")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .background(Color.indigo.opacity(0.15), in: .capsule)
            .foregroundStyle(Color.indigo)
            .accessibilityLabel(Text("Pro feature"))
            .accessibilityIdentifier(AXID.proBadge)
    }
}
