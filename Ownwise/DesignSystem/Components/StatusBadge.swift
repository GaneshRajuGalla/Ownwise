import SwiftUI

struct StatusBadge: View {
    let status: CoverageStatus
    var body: some View {
        Label(status.label, systemImage: Palette.icon(for: status))
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .background(Palette.color(for: status).opacity(0.15), in: .capsule)
            .foregroundStyle(Palette.color(for: status))
    }
}
