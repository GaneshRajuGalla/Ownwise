import SwiftUI

struct SectionCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            if let title { Text(title).font(.headline) }
            content()
        }
        .padding(DS.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: DS.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).strokeBorder(Color(.separator), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}
