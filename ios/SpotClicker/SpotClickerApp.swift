import SwiftUI
import UserNotifications

@main
struct SpotClickerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppModel.shared)
                .environmentObject(AppModel.shared.location)
                .environmentObject(AppModel.shared.clicker)
                .environmentObject(AppModel.shared.notifier)
                .tint(SpotTheme.ink)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        _ = AppModel.shared
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let value = response.notification.request.content.userInfo["spotID"] as? String,
              let id = UUID(uuidString: value) else { return }
        AppModel.shared.selectedSpotID = id
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

