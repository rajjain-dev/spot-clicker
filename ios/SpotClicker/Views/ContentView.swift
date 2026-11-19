import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var notifier: Notifier
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapScreen().tabItem { Label("Map", systemImage: "map") }.tag(0)
            SpotsScreen().tabItem { Label("Spots", systemImage: "square.stack") }.tag(1)
            ClickerScreen().tabItem { Label("Clicker", systemImage: "button.programmable.square") }.tag(2)
        }
        .sheet(item: selectedSpot) { spot in SpotDetailScreen(spotID: spot.id) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { notifier.refresh() } }
    }

    private var selectedSpot: Binding<Spot?> {
        Binding(get: { model.spots.first { $0.id == model.selectedSpotID } },
                set: { model.selectedSpotID = $0?.id })
    }

}

