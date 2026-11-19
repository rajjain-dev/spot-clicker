import XCTest
@testable import SpotClickerCore

final class SpotRepositoryTests: XCTestCase {
    private var directory: URL!
    private let date = Date(timeIntervalSince1970: 1_793_448_000)
    private var fix: LocationFix {
        LocationFix(latitude: 40.732, longitude: -74.002, accuracy: 12, timestamp: date)
    }
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func store() throws -> SpotRepository { try SpotRepository(fileURL: directory.appendingPathComponent("spots.json")) }

    func testCapturesEditsAndMovesSurviveRelaunch() throws {
        let repository = try store()
        let liked = try repository.add(list: .liked, location: fix, at: date)
        let wanted = try repository.add(list: .wantToGo, location: fix, at: date.addingTimeInterval(1))
        try repository.update(id: liked.id, name: "  Corner cafe ", note: "Window seats", list: .wantToGo)
        var reloaded = try store()
        XCTAssertEqual(reloaded.spots.map(\.id), [wanted.id, liked.id])
        XCTAssertEqual(reloaded.spots.last?.name, "Corner cafe")
        XCTAssertEqual(reloaded.spots.last?.note, "Window seats")
        try reloaded.move(id: wanted.id, to: .liked)
        reloaded = try store()
        XCTAssertEqual(reloaded.spots.first?.list, .liked)
        try reloaded.delete(id: liked.id)
        XCTAssertEqual(try store().spots.count, 1)
    }

    func testUndoRespectsWindowAndSkipsExamples() throws {
        let repository = try store()
        let first = try repository.add(list: .liked, location: fix, at: date)
        try repository.addExamples(at: date.addingTimeInterval(500))
        XCTAssertNil(try repository.removeLatest(at: date.addingTimeInterval(601)))
        XCTAssertEqual(try repository.removeLatest(at: date.addingTimeInterval(600))?.id, first.id)
        XCTAssertNil(try repository.removeLatest(at: date.addingTimeInterval(600)))
        XCTAssertEqual(repository.spots.count, 3)
    }

    func testRejectsStaleInvalidAndInaccurateLocations() throws {
        let repository = try store()
        for invalid in [
            LocationFix(latitude: .nan, longitude: 0, accuracy: 1, timestamp: date),
            LocationFix(latitude: 91, longitude: 0, accuracy: 1, timestamp: date),
            LocationFix(latitude: 0, longitude: 0, accuracy: -1, timestamp: date),
            LocationFix(latitude: 0, longitude: 0, accuracy: 151, timestamp: date),
            LocationFix(latitude: 0, longitude: 0, accuracy: 1, timestamp: date.addingTimeInterval(-31))
        ] {
            XCTAssertThrowsError(try repository.add(list: .liked, location: invalid, at: date))
        }
        XCTAssertTrue(repository.spots.isEmpty)
        let delayedFix = LocationFix(latitude: 40, longitude: -74, accuracy: 10, timestamp: date.addingTimeInterval(10))
        let captured = try repository.add(list: .liked, location: delayedFix, at: date, validationDate: date.addingTimeInterval(10))
        XCTAssertEqual(captured.createdAt, date)
        XCTAssertEqual(captured.location.timestamp, delayedFix.timestamp)
    }

    func testWriteFailureDoesNotPublishSuccess() throws {
        let blocker = directory.appendingPathComponent("file-not-directory")
        try Data("blocked".utf8).write(to: blocker)
        let repository = try SpotRepository(fileURL: blocker.appendingPathComponent("spots.json"))
        XCTAssertThrowsError(try repository.add(list: .liked, location: fix, at: date))
        XCTAssertTrue(repository.spots.isEmpty)
    }

    func testUnreadableFileIsPreserved() throws {
        let file = directory.appendingPathComponent("spots.json")
        let original = Data("not json".utf8)
        try original.write(to: file)
        XCTAssertThrowsError(try store())
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testCSVQuotesMultilineTextAndProtectsFormulaCells() throws {
        let repository = try store()
        let spot = try repository.add(list: .liked, location: fix, at: date)
        try repository.update(id: spot.id, name: "Cafe, \"next door\"", note: "=SUM(A1)\nsecond line", list: .liked)
        XCTAssertTrue(repository.csv.contains("\"Cafe, \"\"next door\"\"\""))
        XCTAssertTrue(repository.csv.contains("\"'=SUM(A1)\nsecond line\""))
        XCTAssertTrue(repository.csv.contains(",-74.002,"))
    }

    func testBluetoothDuplicateWrapAndReconnect() {
        var decoder = ClickDecoder()
        XCTAssertEqual(decoder.decode(Data([1, 255])), .single)
        XCTAssertNil(decoder.decode(Data([1, 255])))
        XCTAssertEqual(decoder.decode(Data([2, 0])), .double)
        XCTAssertNil(decoder.decode(Data([99, 1])))
        XCTAssertNil(decoder.decode(Data([1])))
        decoder.reset()
        XCTAssertEqual(decoder.decode(Data([3, 0])), .long)
    }
}

