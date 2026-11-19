import Foundation

public enum SpotList: String, Codable, CaseIterable, Identifiable, Sendable {
    case liked = "Liked"
    case wantToGo = "Want to go"
    public var id: String { rawValue }
    public var other: SpotList { self == .liked ? .wantToGo : .liked }
    public var symbol: String { self == .liked ? "heart.fill" : "bookmark.fill" }
}

public enum CaptureSource: String, Codable, Sendable {
    case phone, clicker, sample
}

public struct LocationFix: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var accuracy: Double
    public var timestamp: Date

    public init(latitude: Double, longitude: Double, accuracy: Double, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
    }

    public var hasValidCoordinates: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude)
            && (-180...180).contains(longitude) && accuracy.isFinite && accuracy >= 0
    }

    public func isUsable(at date: Date, maximumAge: TimeInterval = 30, maximumAccuracy: Double = 150) -> Bool {
        let age = date.timeIntervalSince(timestamp)
        return hasValidCoordinates && age >= -5 && age <= maximumAge && accuracy <= maximumAccuracy
    }
}

public struct Spot: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var list: SpotList
    public let location: LocationFix
    public let source: CaptureSource
    public var name: String
    public var note: String

    public init(id: UUID = UUID(), createdAt: Date = Date(), list: SpotList, location: LocationFix,
                source: CaptureSource = .phone, name: String = "", note: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.list = list
        self.location = location
        self.source = source
        self.name = name
        self.note = note
    }

    public var title: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Spot at \(createdAt.formatted(date: .omitted, time: .shortened))" : trimmed
    }

    public var googleMapsURL: URL {
        var parts = URLComponents(string: "https://www.google.com/maps/search/")!
        parts.queryItems = [URLQueryItem(name: "api", value: "1"),
                            URLQueryItem(name: "query", value: "\(location.latitude),\(location.longitude)")]
        return parts.url!
    }

    public var appleMapsURL: URL {
        var parts = URLComponents(string: "https://maps.apple.com/")!
        parts.queryItems = [URLQueryItem(name: "ll", value: "\(location.latitude),\(location.longitude)"),
                            URLQueryItem(name: "q", value: title)]
        return parts.url!
    }
}

public enum ClickType: UInt8, Sendable {
    case single = 1, double = 2, long = 3
}

/// Notifications are session-scoped: reconnecting a restarted clicker resets its sequence.
public struct ClickDecoder {
    private var lastSequence: UInt8?
    public init() {}
    public mutating func reset() { lastSequence = nil }
    public mutating func decode(_ bytes: Data) -> ClickType? {
        guard bytes.count == 2, let type = ClickType(rawValue: bytes[bytes.startIndex]) else { return nil }
        let sequence = bytes[bytes.startIndex + 1]
        guard sequence != lastSequence else { return nil }
        lastSequence = sequence
        return type
    }
}

