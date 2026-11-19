import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var clicker: ClickerService
    @State private var filter: SpotFilter = .all
    @State private var selection: UUID?
    @State private var position: MapCameraPosition = .region(Self.village)
    static let village = MKCoordinateRegion(center: .init(latitude: 40.7322, longitude: -74.0025),
                                            latitudinalMeters: 1100, longitudinalMeters: 1100)

    var body: some View {
        NavigationStack {
            Map(position: $position, selection: $selection) {
                UserAnnotation()
                ForEach(model.spots.filter { filter.includes($0) }) { spot in
                    Marker(spot.source == .sample ? "Example: \(spot.title)" : spot.title,
                           systemImage: spot.list.symbol, coordinate: spot.coordinate)
                        .tint(spot.list.color).tag(spot.id)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapUserLocationButton(); MapCompass(); MapScaleView() }
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) { AppStatusBanner(); header }
            }
            .safeAreaInset(edge: .bottom) { capturePanel }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: selection) { _, id in
                if let id { model.selectedSpotID = id; selection = nil }
            }
            .onChange(of: model.spots.first?.id) { _, _ in
                if let spot = model.spots.first {
                    withAnimation {
                        position = .region(MKCoordinateRegion(center: spot.coordinate,
                                                             latitudinalMeters: 700, longitudinalMeters: 700))
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPOT CLICKER").font(.caption2.weight(.heavy)).tracking(3).foregroundStyle(.secondary)
                    Text("Keep the moment.").font(.system(.title, design: .rounded, weight: .bold))
                }
                Spacer()
                Image(systemName: "location.square.fill")
                    .font(.system(size: 34)).foregroundStyle(SpotTheme.ink)
                    .accessibilityHidden(true)
            }
            ListFilter(selection: $filter)
        }
        .padding(20)
        .background(SpotTheme.canvas)
    }

    private var capturePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(clicker.ready ? .green : SpotTheme.orange).frame(width: 7, height: 7)
                Text(clicker.ready ? "Clicker ready" : "Try a click, right here")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(model.realSpotCount) saved").font(.caption).foregroundStyle(.secondary)
            }
            CaptureButtons()
            if model.spots.isEmpty {
                Text("See something you like? Save where you're standing. Name it later.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(SpotTheme.canvas, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
    }
}

