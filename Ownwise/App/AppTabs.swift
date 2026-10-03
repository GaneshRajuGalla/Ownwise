import SwiftUI

struct AppTabs: View {
    @State private var showScan = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeView() }
                .accessibilityIdentifier(AXID.tabHome)
            Tab("Items", systemImage: "shippingbox") { ItemsView() }
                .accessibilityIdentifier(AXID.tabItems)
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
                .accessibilityIdentifier(AXID.tabSettings)
            Tab(role: .search) { SearchView() }
                .accessibilityIdentifier(AXID.tabSearch)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            GlassScanButton { showScan = true }
        }
        .sheet(isPresented: $showScan) {
            ScanFlow()
        }
    }
}
