import SwiftUI
import UIKit

struct ClickerScreen: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var clicker: ClickerService
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var notifier: Notifier
    @AppStorage("clickerFeedback") private var clickerFeedback = true
    @State private var exporting = false
    @State private var confirmForget = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 18) {
                        ClickerIllustration().frame(height: 120)
                        Text("Good finds. One click away.")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Text(clicker.ready ? "Connected and ready for your next walk." : "Your phone can be your clicker for now.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
                Section("Your clicker") {
                    LabeledContent("Status", value: clicker.status)
                    if let name = clicker.pairedName {
                        LabeledContent("Connected accessory", value: name)
                        Toggle("Clicker save feedback", isOn: $clickerFeedback)
                        Button("Forget clicker", role: .destructive) { confirmForget = true }.disabled(!clicker.setupReady)
                    } else {
                        Button { clicker.setup() } label: { Label("Set up a clicker", systemImage: "plus.circle.fill") }
                    }
                }
                Section {
                    CaptureButtons().listRowBackground(Color.clear).listRowInsets(.init())
                    Button { model.handle(.long) } label: { Label("Undo last capture", systemImage: "arrow.uturn.backward") }
                        .disabled(!model.canSave).accessibilityIdentifier("undoCapture")
                    if model.notice != nil || model.storageError != nil {
                        AppStatusBanner().listRowInsets(.init())
                    }
                } header: { Text("Try it without hardware") }
                footer: { Text("One click saves to Liked. Two clicks save to Want to go. Holding undoes the last capture within 10 minutes. These controls save your actual location.") }

                Section("Permissions") {
                    LabeledContent("Location", value: location.statusText)
                    LabeledContent("Precise Location", value: location.precise ? "On" : "Off")
                    if location.authorization == .notDetermined {
                        Button("Allow location") { location.requestPermission() }
                    }
                    if location.authorization == .authorizedWhenInUse {
                        Button("Enable pocket saving") { location.requestPocketPermission() }
                    }
                    LabeledContent("Notifications", value: notifier.statusText)
                    if notifier.status == .notDetermined {
                        Button("Allow save notifications") { Task { await notifier.requestPermission() } }
                    }
                    Button("Open iPhone Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }

                Section {
                    Button { exporting = true } label: { Label("Export spots as CSV", systemImage: "square.and.arrow.up") }
                        .disabled(model.spots.isEmpty).accessibilityIdentifier("exportSpots")
                    LabeledContent("Storage", value: "On this iPhone")
                } header: { Text("Your data") }
                footer: { Text("Captures stay on this phone. Saving works without internet when GPS is available. Map imagery and external maps may need a connection.") }

                Section {
                    if model.spots.contains(where: { $0.source == .sample }) {
                        Button("Remove example pins") { model.removeExamples() }
                    } else {
                        Button("Explore with example pins") { model.addExamples() }
                            .accessibilityIdentifier("addExamples")
                    }
                } header: { Text("Local demo") }
                footer: { Text("Example pins let you explore names, notes, and lists. They're labeled, excluded from undo, and can be removed together.") }

                Section {
                    Text("Pocket saving needs a connected clicker, suitable location permission, and real-device testing. After restarting your iPhone, unlock it once. If Bluetooth is off or the clicker is out of range, presses aren't saved for later.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Before a walk") }
            }
            .scrollContentBackground(.hidden).background(SpotTheme.canvas)
            .navigationTitle("Your clicker")
            .fileExporter(isPresented: $exporting, document: model.csvDocument,
                          contentType: .commaSeparatedText, defaultFilename: "Spot-Clicker-Spots") { result in
                if case .failure(let error) = result {
                    model.notice = SaveNotice(text: "Export failed", detail: error.localizedDescription, isError: true)
                }
            }
            .alert("Clicker setup", isPresented: Binding(get: { clicker.errorMessage != nil }, set: { if !$0 { clicker.errorMessage = nil } })) {
                Button("OK") { clicker.errorMessage = nil }
            } message: { Text(clicker.errorMessage ?? "") }
            .confirmationDialog("Forget this clicker?", isPresented: $confirmForget, titleVisibility: .visible) {
                Button("Forget clicker", role: .destructive) { clicker.forget() }
            }
        }
    }
}

struct ClickerIllustration: View {
    var body: some View {
        ZStack {
            Ellipse().fill(SpotTheme.ink.opacity(0.10)).frame(width: 160, height: 24).offset(y: 49)
            RoundedRectangle(cornerRadius: 18).fill(SpotTheme.ink.opacity(0.20))
                .frame(width: 104, height: 90).offset(y: 13)
            RoundedRectangle(cornerRadius: 18).fill(SpotTheme.ink)
                .frame(width: 104, height: 86).offset(y: 3)
            RoundedRectangle(cornerRadius: 14).fill(SpotTheme.canvas)
                .frame(width: 78, height: 60).offset(y: -7)
            Image(systemName: "mappin.and.ellipse").font(.system(size: 31, weight: .semibold))
                .foregroundStyle(SpotTheme.ink).offset(y: -7)
            Circle().stroke(SpotTheme.ink.opacity(0.5), lineWidth: 5).frame(width: 28, height: 28)
                .offset(x: 64, y: 31)
        }
        .rotationEffect(.degrees(-12))
        .accessibilityHidden(true)
    }
}

