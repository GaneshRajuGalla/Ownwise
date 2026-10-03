import SwiftUI
import UserNotifications

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            page1.tag(0)
            page2.tag(1)
            page3.tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    var page1: some View {
        VStack(spacing: DS.Space.xl) {
            Image(systemName: "doc.viewfinder").font(.system(size: 72)).foregroundStyle(.indigo)
            Text("Scan receipts").font(.largeTitle.bold())
            Text("One scan captures your purchase details — 100% on-device.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Continue") { page = 1 }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier(AXID.onboardingContinue)
        }
        .padding()
    }

    var page2: some View {
        VStack(spacing: DS.Space.xl) {
            Image(systemName: "bell.badge").font(.system(size: 72)).foregroundStyle(.indigo)
            Text("Never miss a return or warranty").font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text("Get reminders before return windows, warranties and service dates.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Allow reminders") {
                Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) }
                page = 2
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier(AXID.onboardingContinue)
        }
        .padding()
    }

    var page3: some View {
        VStack(spacing: DS.Space.xl) {
            Image(systemName: "lock.shield").font(.system(size: 72)).foregroundStyle(.indigo)
            Text("Private by design").font(.largeTitle.bold())
            Text("No account. No cloud. No tracking. Your data never leaves your iPhone.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Get started") { onFinish() }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier(AXID.onboardingGetStarted)
        }
        .padding()
    }
}
