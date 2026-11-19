import CoreLocation
import Combine

enum CaptureError: LocalizedError {
    case locationDenied, noLocation, inaccurateLocation
    var errorDescription: String? {
        switch self {
        case .locationDenied: return "Allow location in Settings to save where you are."
        case .noLocation: return "We couldn't find your location. Try again near a window or outdoors."
        case .inaccurateLocation: return "Your location isn't accurate enough yet. Try again outdoors with Precise Location enabled."
        }
    }
}

@MainActor
// CLLocationManager is created on the main actor and delivers delegates on that run loop.
final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var precise = true
    private let manager = CLLocationManager()
    private var permissionWaiter: CheckedContinuation<Void, Never>?
    private var locationWaiter: CheckedContinuation<LocationFix, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var requestID: UUID?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = manager.authorizationStatus
        precise = manager.accuracyAuthorization == .fullAccuracy
        manager.allowsBackgroundLocationUpdates = true
    }

    var statusText: String {
        switch authorization {
        case .authorizedAlways: return "Always allowed"
        case .authorizedWhenInUse: return "While using the app"
        case .denied: return "Not allowed"
        case .restricted: return "Restricted"
        default: return "Not set up"
        }
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }
    func requestPocketPermission() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
        else if authorization == .authorizedWhenInUse { manager.requestAlwaysAuthorization() }
    }

    func currentLocation() async throws -> LocationFix {
        if authorization == .notDetermined {
            await withCheckedContinuation { continuation in
                permissionWaiter = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        try Task.checkCancellation()
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            throw CaptureError.locationDenied
        }
        if let last = manager.location {
            let fix = Self.fix(last)
            if fix.isUsable(at: Date(), maximumAge: 5, maximumAccuracy: 30) { return fix }
        }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                requestID = id
                locationWaiter = continuation
                manager.requestLocation()
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(12)) } catch { return }
                    guard self?.requestID == id else { return }
                    self?.finish(.failure(CaptureError.noLocation))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.requestID == id else { return }
                self?.finish(.failure(CancellationError()))
            }
        }
    }

    private static func fix(_ value: CLLocation) -> LocationFix {
        LocationFix(latitude: value.coordinate.latitude, longitude: value.coordinate.longitude,
                    accuracy: value.horizontalAccuracy, timestamp: value.timestamp)
    }

    private func finish(_ result: Result<LocationFix, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        requestID = nil
        manager.stopUpdatingLocation()
        let waiter = locationWaiter
        locationWaiter = nil
        waiter?.resume(with: result)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let fix = Self.fix(location)
        finish(fix.isUsable(at: Date()) ? .success(fix) : .failure(CaptureError.inaccurateLocation))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(CaptureError.noLocation))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        precise = manager.accuracyAuthorization == .fullAccuracy
        if authorization != .notDetermined {
            permissionWaiter?.resume()
            permissionWaiter = nil
        }
    }
}

