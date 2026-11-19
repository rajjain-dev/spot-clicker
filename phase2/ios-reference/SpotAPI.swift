import Foundation

/// Talks to the Google Apps Script web app (phase2/backend/Code.gs).
/// NOTE: v1 is moving to local-only pins; see HANDOFF.md section 7. This file is
/// kept so the current code still compiles and so phase 2 can reuse it.
struct SpotAPI {
    let baseURL: URL
    let secret: String

    enum APIError: LocalizedError {
        case notConfigured
        case server(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Add the backend URL and secret in the Clicker tab."
            case .server(let message): return message
            case .badResponse: return "The backend sent something unexpected."
            }
        }
    }

    private struct Response: Decodable {
        let ok: Bool
        let error: String?
        let spot: Spot?
        let spots: [Spot]?
    }

    /// Reads the backend settings saved in the Clicker tab.
    static func fromSettings() -> SpotAPI? {
        let defaults = UserDefaults.standard
        guard let urlString = defaults.string(forKey: "backendURL")?.trimmingCharacters(in: .whitespaces),
              !urlString.isEmpty, let url = URL(string: urlString),
              let secret = defaults.string(forKey: "sharedSecret"), !secret.isEmpty else { return nil }
        return SpotAPI(baseURL: url, secret: secret)
    }

    func ping() async throws {
        _ = try await post(["action": "ping"])
    }

    func save(_ click: PendingClick) async throws -> Spot {
        let iso = ISO8601DateFormatter().string(from: click.pressedAt)
        let r = try await post([
            "action": "save",
            "clientId": click.id,
            "list": click.list.rawValue,
            "lat": click.lat,
            "lng": click.lng,
            "accuracy": click.accuracy,
            "pressedAt": iso
        ])
        guard let spot = r.spot else { throw APIError.badResponse }
        return spot
    }

    func list() async throws -> [Spot] {
        try await post(["action": "list"]).spots ?? []
    }

    func update(id: String, list: SpotList? = nil, placeId: String? = nil) async throws -> Spot {
        var body: [String: Any] = ["action": "update", "id": id]
        if let list { body["list"] = list.rawValue }
        if let placeId { body["placeId"] = placeId }
        guard let spot = try await post(body).spot else { throw APIError.badResponse }
        return spot
    }

    func delete(id: String) async throws {
        _ = try await post(["action": "delete", "id": id])
    }

    // Apps Script answers a POST with a redirect to the result. URLSession follows it
    // with a GET, which is what Apps Script expects.
    private func post(_ body: [String: Any]) async throws -> Response {
        var payload = body
        payload["secret"] = secret
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("text/plain;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response: Response
        do {
            response = try JSONDecoder.spotDecoder.decode(Response.self, from: data)
        } catch {
            throw APIError.server("Couldn't read the backend's reply. Check the URL and that the web app is deployed for Anyone.")
        }
        if !response.ok { throw APIError.server(response.error ?? "Unknown backend error") }
        return response
    }
}
