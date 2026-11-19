import SwiftUI
import CoreLocation

enum SpotTheme {
    static let ink = Color("Ink")
    static let canvas = Color("Canvas")
    static let pink = Color(red: 0.85, green: 0.24, blue: 0.40)
    static let orange = Color(red: 0.78, green: 0.36, blue: 0.08)
}

extension SpotList {
    var color: Color { self == .liked ? SpotTheme.pink : SpotTheme.orange }
}

extension Spot {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
}

enum SpotFilter: String, CaseIterable, Identifiable {
    case all = "All", liked = "Liked", wantToGo = "Want to go"
    var id: Self { self }
    func includes(_ spot: Spot) -> Bool {
        self == .all || (self == .liked && spot.list == .liked) || (self == .wantToGo && spot.list == .wantToGo)
    }
}

struct ListFilter: View {
    @Binding var selection: SpotFilter
    var body: some View {
        Picker("Show spots", selection: $selection) {
            ForEach(SpotFilter.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("listFilter")
    }
}

struct CaptureButtons: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        HStack(spacing: 12) {
            captureButton(.liked, type: .single, hint: "One click", identifier: "saveLiked")
            captureButton(.wantToGo, type: .double, hint: "Two clicks", identifier: "saveWantToGo")
        }
        .disabled(!model.canSave)
    }

    private func captureButton(_ list: SpotList, type: ClickType, hint: String, identifier: String) -> some View {
        Button { model.handle(type) } label: {
            HStack(spacing: 10) {
                Image(systemName: list.symbol).font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(list.rawValue).font(.subheadline.bold())
                    Text(hint).font(.caption)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 62)
            .foregroundStyle(list.color)
            .background(list.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save to \(list.rawValue)")
        .accessibilityHint("Saves your current GPS location")
        .accessibilityIdentifier(identifier)
    }
}

struct SpotIcon: View {
    let list: SpotList
    var body: some View {
        Image(systemName: list.symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(list.color)
            .frame(width: 46, height: 46)
            .background(list.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct SpotRow: View {
    let spot: Spot
    var body: some View {
        HStack(spacing: 12) {
            SpotIcon(list: spot.list)
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(spot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
                if spot.source == .sample { Text("Example pin").font(.caption2.bold()).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct AppStatusBanner: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            if let error = model.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).padding().frame(maxWidth: .infinity)
                    .background(.red.opacity(0.12))
            }
            if let notice = model.notice {
                HStack(spacing: 12) {
                    if model.isSaving { ProgressView() }
                    else {
                        Image(systemName: notice.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(notice.isError ? .red : .green)
                    }
                    Button { if let id = notice.spotID { model.selectedSpotID = id } } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notice.text).font(.subheadline.bold())
                            Text(notice.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(notice.spotID == nil)
                    .accessibilityIdentifier("saveNotice")
                    if !model.isSaving {
                        Button { model.notice = nil } label: { Image(systemName: "xmark").font(.caption.bold()) }
                            .accessibilityLabel("Dismiss message")
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(SpotTheme.canvas)
            }
        }
    }
}

