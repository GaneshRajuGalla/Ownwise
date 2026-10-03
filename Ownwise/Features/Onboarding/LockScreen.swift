import SwiftUI

struct LockScreen: View {
    @Environment(AppLock.self) private var appLock
    var body: some View {
        VStack(spacing: DS.Space.xl) {
            Image(systemName: "faceid").font(.system(size: 64)).foregroundStyle(.indigo)
            Text("Ownwise is locked").font(.title2.bold())
            Button("Unlock") { Task { await appLock.unlock() } }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier(AXID.unlockButton)
        }
        .task { if appLock.isLocked { await appLock.unlock() } }
    }
}
