import SwiftUI

struct StatusBadge: View {
    let status: CoverageStatus
    var body: some View {
        Label(status.label, systemImage: Palette.icon(for: status))
            .font(.caption.weight(.semibold))
            // Never fixed-size: at the largest accessibility sizes the badge compresses and
            // scales instead of overflowing the row.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .background(Palette.color(for: status).opacity(0.15), in: .capsule)
            .foregroundStyle(Palette.color(for: status))
    }
}
