import SwiftUI
import MapKit

struct SpotDetailScreen: View {
    let spotID: UUID
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var list: SpotList = .liked
    @State private var loaded = false
    @State private var confirmDelete = false
    @State private var confirmDiscard = false
    @State private var saveFailed = false
    private var spot: Spot? { model.spots.first { $0.id == spotID } }
    private var hasChanges: Bool {
        guard let spot, loaded else { return false }
        return name != spot.name || note != spot.note || list != spot.list
    }

    var body: some View {
        NavigationStack {
            if let spot {
                Form {
                    Section {
                        Map(initialPosition: .region(MKCoordinateRegion(center: spot.coordinate,
                                                                       latitudinalMeters: 350, longitudinalMeters: 350))) {
                            MapCircle(center: spot.coordinate, radius: spot.location.accuracy)
                                .foregroundStyle(spot.list.color.opacity(0.12))
                            Marker(spot.title, systemImage: spot.list.symbol, coordinate: spot.coordinate).tint(spot.list.color)
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll))
                        .frame(height: 210).allowsHitTesting(false).listRowInsets(.init())
                    }
                    if spot.source == .sample {
                        Section { Label("Example pin · not a real capture", systemImage: "sparkles").font(.footnote) }
                    }
                    Section("Make it yours") {
                        TextField("Give this spot a name", text: $name)
                            .accessibilityIdentifier("spotName")
                        TextField("What caught your eye?", text: $note, axis: .vertical)
                            .lineLimit(3...6).accessibilityIdentifier("spotNote")
                        Picker("Saved to", selection: $list) {
                            ForEach(SpotList.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                        }
                    }
                    Section("The moment") {
                        LabeledContent("Saved", value: spot.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("GPS accuracy", value: "About \(Int(spot.location.accuracy.rounded())) m")
                        LabeledContent("Coordinates") {
                            Text(String(format: "%.5f, %.5f", spot.location.latitude, spot.location.longitude))
                                .monospacedDigit().font(.caption).textSelection(.enabled)
                        }
                        LabeledContent("Captured with", value: spot.source == .clicker ? "Keychain clicker" : spot.source == .sample ? "Example data" : "This iPhone")
                    }
                    Section {
                        Link(destination: spot.appleMapsURL) { Label("Open in Apple Maps", systemImage: "map") }
                        Link(destination: spot.googleMapsURL) { Label("Open in Google Maps", systemImage: "arrow.up.forward.square") }
                    } footer: { Text("These links open the saved coordinate. Business identification comes later.") }
                    Section {
                        Button("Delete spot", role: .destructive) { confirmDelete = true }
                    }
                }
                .scrollContentBackground(.hidden).background(SpotTheme.canvas)
                .navigationTitle(spot.name.isEmpty ? "A good find" : spot.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if hasChanges { Button("Cancel") { confirmDiscard = true } }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(hasChanges ? "Save" : "Done") {
                            if !hasChanges || model.update(id: spotID, name: name, note: note, list: list) { dismiss() }
                            else { saveFailed = true }
                        }
                        .fontWeight(.semibold).accessibilityIdentifier("saveSpotDetails")
                    }
                }
                .interactiveDismissDisabled(hasChanges)
                .alert("Changes weren't saved", isPresented: $saveFailed) {
                    Button("OK", role: .cancel) {}
                } message: { Text(model.notice?.detail ?? "Please try again.") }
                .confirmationDialog("Delete this spot?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete spot", role: .destructive) { if model.delete(spot) { dismiss() } }
                }
                .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                    Button("Discard changes", role: .destructive) { dismiss() }
                }
                .task {
                    guard !loaded else { return }
                    name = spot.name; note = spot.note; list = spot.list; loaded = true
                }
            } else {
                ContentUnavailableView("Spot removed", systemImage: "trash")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
    }
}

