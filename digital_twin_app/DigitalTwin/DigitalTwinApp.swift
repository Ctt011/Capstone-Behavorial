import SwiftUI
import UserNotifications

@main
struct DigitalTwinApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .onAppear {
                    // Re-enable background delivery on app launch
                    if healthKitManager.isAuthorized {
                        healthKitManager.setupBackgroundDelivery()
                    }
                    // Clear any pending termination notifications since user is back
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["terminationReminder"])
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // User is back - cancel any pending termination reminder
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["terminationReminder"])
                
                // Refresh HealthKit data and catch up on missed stress predictions.
                // While the app was suspended/background the stress prediction timer
                // stops firing, leaving gaps in drain tracking. refreshAllData()
                // pulls the latest samples, then catchUpMissedPredictions() fills
                // in the missed intervals with a conservative drain estimate.
                Task {
                    await healthKitManager.refreshAllData()
                    BodyBatteryManager.shared.catchUpMissedPredictions()
                }
            }
        }
    }
}

// MARK: - App Delegate for Background Handling
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Migrate large data from UserDefaults to file storage (one-time)
        PersistenceManager.migrateFromUserDefaultsIfNeeded()
        
        // Set notification default for existing users
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
        }
        
        // Request notification permissions early
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                debugLog("✅ Notification permission granted on launch")
            }
        }
        
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Clear any old notifications from previous sessions
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["terminationReminder"])
        
        return true
    }
    
    // Handle background fetch
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // HealthKit background delivery is handled by observer queries
        completionHandler(.newData)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // App is being terminated - send ONE notification
        sendTerminationNotification()
    }
    
    private func sendTerminationNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Stay connected for better insights 🔋"
        content.body = "Re-open PhysioTwin to keep tracking your body battery and stress levels throughout the day."
        content.sound = .default
        
        // Trigger after 1 second - only once, not repeating
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "terminationReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
