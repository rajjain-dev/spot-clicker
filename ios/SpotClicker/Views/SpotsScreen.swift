import SwiftUI

struct SpotsScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var filter: SpotFilter = .all
    @State private var deleting: Spot?
    private var filtered: [Spot] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.spots.filter { filter.includes($0) && (query.isEmpty
            || $0.title.localizedCaseInsensitiveContains(query) || $0.note.localizedCaseInsensitiveContains(query)) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section { ListFilter(selection: $filter).listRowBackground(Color.clear).listRowInsets(.init()) }
                if model.notice != nil || model.storageError != nil {
                    Section { AppStatusBanner().listRowInsets(.init()) }
                }
                ForEach(SpotList.allCases) { list in
                    let items = filtered.filter { $0.list == list }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { spot in
                                Button { model.selectedSpotID = spot.id } label: { SpotRow(spot: spot) }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) { deleting = spot } label: { Label("Delete", systemImage: "trash") }
                                        Button { model.move(spot) } label: { Label("Move", systemImage: "arrow.left.arrow.right") }
                                            .tint(spot.list.other.color)
                                    }
                            }
                        } header: { Text("\(list.rawValue) · \(items.count)") }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SpotTheme.canvas)
            .searchable(text: $search, prompt: "Search names and notes")
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(model.spots.isEmpty ? "Your next good find" : "No matching spots",
                                           systemImage: model.spots.isEmpty ? "mappin.and.ellipse" : "magnifyingglass",
                                           description: Text(model.spots.isEmpty
                                                ? "Save a place from the Map tab. It'll be waiting here when you have time."
                                                : "Try another name, note, or list."))
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle("Your spots")
            .confirmationDialog("Delete this spot?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                if let spot = deleting {
                    Button("Delete spot", role: .destructive) { _ = model.delete(spot); deleting = nil }
                }
            }
        }
    }
}
