import Foundation

public enum SpotStorageError: LocalizedError {
    case invalidLocation, invalidArchive, unsupportedVersion, missingSpot
    public var errorDescription: String? {
        switch self {
        case .invalidLocation: return "A recent, accurate location is needed. Try again outdoors."
        case .invalidArchive: return "Your saved spots file could not be read. It has been kept unchanged."
        case .unsupportedVersion: return "This spots file was made by a newer app. It has been kept unchanged."
        case .missingSpot: return "This spot has already been removed."
        }
    }
}

/// All mutations write a complete atomic snapshot before publishing the new state.
/// Call on one serial executor (the app uses the main actor).
public final class SpotRepository {
    public private(set) var spots: [Spot]
    public let fileURL: URL
    private struct Snapshot: Codable { let version: Int; let spots: [Spot] }

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { spots = []; return }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot: Snapshot
        do { snapshot = try decoder.decode(Snapshot.self, from: data) }
        catch { throw SpotStorageError.invalidArchive }
        guard snapshot.version == 1 else { throw SpotStorageError.unsupportedVersion }
        guard Set(snapshot.spots.map(\.id)).count == snapshot.spots.count,
              snapshot.spots.allSatisfy({ $0.location.hasValidCoordinates }) else {
            throw SpotStorageError.invalidArchive
        }
        spots = snapshot.spots.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    public func add(list: SpotList, location: LocationFix, source: CaptureSource = .phone,
                    at date: Date = Date(), validationDate: Date? = nil) throws -> Spot {
        guard location.isUsable(at: validationDate ?? date) else { throw SpotStorageError.invalidLocation }
        let spot = Spot(createdAt: date, list: list, location: location, source: source)
        try commit([spot] + spots)
        return spot
    }

    public func update(id: UUID, name: String, note: String, list: SpotList) throws {
        var next = spots
        guard let index = next.firstIndex(where: { $0.id == id }) else { throw SpotStorageError.missingSpot }
        next[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        next[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        next[index].list = list
        try commit(next)
    }

    public func move(id: UUID, to list: SpotList) throws {
        guard let spot = spots.first(where: { $0.id == id }) else { throw SpotStorageError.missingSpot }
        try update(id: id, name: spot.name, note: spot.note, list: list)
    }

    public func delete(id: UUID) throws {
        try commit(spots.filter { $0.id != id })
    }

    @discardableResult
    public func removeLatest(within window: TimeInterval = 600, at date: Date = Date()) throws -> Spot? {
        guard let spot = spots.first(where: { $0.source != .sample }),
              (0...window).contains(date.timeIntervalSince(spot.createdAt)) else { return nil }
        try delete(id: spot.id)
        return spot
    }

    public func addExamples(at date: Date = Date()) throws {
        guard !spots.contains(where: { $0.source == .sample }) else { return }
        let examples: [(String, Double, Double, SpotList)] = [
            ("A coffee stop", 40.73312, -74.00272, .wantToGo),
            ("A quiet corner", 40.73085, -74.00312, .liked),
            ("A shop to revisit", 40.73405, -74.00117, .wantToGo)
        ]
        let samples = examples.enumerated().map { index, item in
            Spot(createdAt: date.addingTimeInterval(Double(-index * 600)), list: item.3,
                 location: LocationFix(latitude: item.1, longitude: item.2, accuracy: 10, timestamp: date),
                 source: .sample, name: item.0, note: "Example pin for exploring the app. This is not a real capture or an identified business.")
        }
        try commit(spots + samples)
    }

    public func removeExamples() throws { try commit(spots.filter { $0.source != .sample }) }

    public var csv: String {
        let iso = ISO8601DateFormatter()
        var rows = ["name,list,latitude,longitude,saved_at,accuracy_m,note,source,location_timestamp"]
        rows += spots.map { spot in
            [Self.csvText(spot.name), Self.csvText(spot.list.rawValue),
             String(spot.location.latitude), String(spot.location.longitude), iso.string(from: spot.createdAt),
             String(spot.location.accuracy), Self.csvText(spot.note), spot.source.rawValue,
             iso.string(from: spot.location.timestamp)].joined(separator: ",")
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    private static func csvText(_ value: String) -> String {
        // Keep user-entered text from becoming a formula when opened in a spreadsheet.
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.first.map { "=+-@".contains($0) } == true ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func commit(_ next: [Spot]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Snapshot(version: 1, spots: next))
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
        spots = next.sorted { $0.createdAt > $1.createdAt }
    }
}
