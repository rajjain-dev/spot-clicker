import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SpotCSV: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct SaveNotice: Equatable {
    let text: String
    let detail: String
    var spotID: UUID? = nil
    var isError = false
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    let location = LocationService()
    let clicker = ClickerService()
    let notifier = Notifier()
    @Published private(set) var spots: [Spot] = []
    @Published private(set) var isSaving = false
    @Published private(set) var storageError: String?
    @Published var selectedSpotID: UUID?
    @Published var notice: SaveNotice?
    private var repository: SpotRepository?
    private struct Action { let type: ClickType; let source: CaptureSource; let date: Date }
    private var actions: [Action] = []
    private var processingTask: Task<Void, Never>?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        let folder = support.appendingPathComponent(testing ? "SpotClicker-UITests" : "SpotClicker", isDirectory: true)
        if testing && ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
            try? FileManager.default.removeItem(at: folder)
        }
        do {
            repository = try SpotRepository(fileURL: folder.appendingPathComponent("spots.json"))
            spots = repository?.spots ?? []
        } catch { storageError = error.localizedDescription }
        clicker.onClick = { [weak self] type in self?.handle(type, source: .clicker) }
    }

    var canSave: Bool { repository != nil && !isSaving }
    var csvDocument: SpotCSV { SpotCSV(text: repository?.csv ?? "") }
    var realSpotCount: Int { spots.filter { $0.source != .sample }.count }

    func handle(_ type: ClickType, source: CaptureSource = .phone) {
        guard repository != nil else { fail(storageError ?? "Saved spots are unavailable.", source: source); return }
        guard type == .long || !isSaving else {
            fail("A capture is already in progress. Wait for confirmation, then click again.", source: source)
            return
        }
        guard actions.count < 20 else { fail("Please wait for the current captures to finish.", source: source); return }
        actions.append(Action(type: type, source: source, date: Date()))
        guard processingTask == nil else { return }
        isSaving = true
        let background = UIApplication.shared.beginBackgroundTask(withName: "Save Spot") { [weak self] in
            Task { @MainActor in self?.processingTask?.cancel() }
        }
        processingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                UIApplication.shared.endBackgroundTask(background)
                self.isSaving = false
                self.processingTask = nil
            }
            while !self.actions.isEmpty {
                let action = self.actions.removeFirst()
                do {
                    try Task.checkCancellation()
                    guard let repository = self.repository else { return }
                    if action.type == .long {
                        if let removed = try repository.removeLatest(at: action.date) {
                            self.publishSpots()
                            if self.selectedSpotID == removed.id { self.selectedSpotID = nil }
                            if action.source == .clicker { self.clicker.send(4) }
                            self.show(SaveNotice(text: "Last spot removed", detail: "\(removed.title) was undone."))
                        } else {
                            self.fail("Undo works on a capture saved in the last 10 minutes.", source: action.source,
                                      title: "Nothing to undo")
                        }
                    } else {
                        self.notice = SaveNotice(text: "Finding your location…", detail: "Your spot will be saved on this iPhone.")
                        let fix = try await self.location.currentLocation()
                        try Task.checkCancellation()
                        let list: SpotList = action.type == .single ? .liked : .wantToGo
                        let spot = try repository.add(list: list, location: fix, source: action.source,
                                                      at: action.date, validationDate: Date())
                        self.publishSpots()
                        if action.source == .clicker { self.clicker.send(list == .liked ? 1 : 2) }
                        self.show(SaveNotice(text: "Saved to \(list.rawValue)",
                                             detail: "Location accurate to about \(Int(fix.accuracy.rounded())) m.", spotID: spot.id))
                    }
                } catch {
                    self.fail(error is CancellationError ? "The save was interrupted. Please try again." : error.localizedDescription,
                              source: action.source)
                    if Task.isCancelled { self.actions.removeAll(); break }
                }
            }
        }
    }

    func update(id: UUID, name: String, note: String, list: SpotList) -> Bool {
        mutate { try $0.update(id: id, name: name, note: note, list: list) }
    }

    func move(_ spot: Spot) { _ = mutate { try $0.move(id: spot.id, to: spot.list.other) } }
    func delete(_ spot: Spot) -> Bool {
        let success = mutate { try $0.delete(id: spot.id) }
        if success && selectedSpotID == spot.id { selectedSpotID = nil }
        return success
    }
    func addExamples() { _ = mutate { try $0.addExamples() } }
    func removeExamples() { _ = mutate { try $0.removeExamples() } }

    private func mutate(_ operation: (SpotRepository) throws -> Void) -> Bool {
        guard let repository else { return false }
        do { try operation(repository); publishSpots(); return true }
        catch { fail(error.localizedDescription, source: .phone); return false }
    }

    private func publishSpots() { spots = repository?.spots ?? [] }
    private func fail(_ message: String, source: CaptureSource, title: String = "Spot not saved") {
        if source == .clicker { clicker.send(3) }
        show(SaveNotice(text: title, detail: message, isError: true))
    }
    private func show(_ notice: SaveNotice) {
        self.notice = notice
        if UIApplication.shared.applicationState == .active {
            UINotificationFeedbackGenerator().notificationOccurred(notice.isError ? .error : .success)
        } else {
            notifier.post(title: notice.text, body: notice.detail, spotID: notice.spotID)
        }
    }
}

