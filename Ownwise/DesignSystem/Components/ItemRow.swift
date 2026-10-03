import SwiftUI

struct ItemRow: View {
    let item: Item
    var body: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 32, height: 32)
                .background(Color.indigo.opacity(0.12), in: .rect(cornerRadius: DS.Radius.chip))
                .frame(width: 32, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: DS.Space.s)
            if let s = worstStatus { StatusBadge(status: s) }
        }
        .padding(.vertical, DS.Space.xs)
    }

    var icon: String {
        switch item.category {
        case .appliance: "washer"
        case .electronics: "tv"
        case .mobile: "iphone"
        case .computer: "laptopcomputer"
        case .furniture: "bed.double"
        case .vehicle: "car"
        case .other: "shippingbox"
        }
    }
    var subtitle: String {
        [item.brand, item.merchant].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    var worstStatus: CoverageStatus? {
        (item.coverages ?? []).map { coverageStatus(of: $0, now: .now) }
            .sorted { rank($0) < rank($1) }.first
    }
    func rank(_ s: CoverageStatus) -> Int {
        switch s { case .serviceDue: 0; case .expiringSoon: 1; case .expired: 2; case .active: 3 }
    }
}
