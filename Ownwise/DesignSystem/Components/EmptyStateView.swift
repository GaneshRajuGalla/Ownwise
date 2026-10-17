import SwiftUI

struct EmptyStateView: View {
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    var systemImage: String
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(AXID.emptyStateCTA)
            }
        }
    }
}
