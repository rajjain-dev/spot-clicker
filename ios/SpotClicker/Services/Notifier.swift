import UserNotifications
import Combine

@MainActor
final class Notifier: ObservableObject {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    var statusText: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "Allowed"
        case .denied: return "Not allowed"
        default: return "Not set up"
        }
    }

    init() { refresh() }

    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in self.status = settings.authorizationStatus }
        }
    }

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        refresh()
    }

    func post(title: String, body: String, spotID: UUID? = nil) {
        guard status == .authorized || status == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let spotID { content.userInfo["spotID"] = spotID.uuidString }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

