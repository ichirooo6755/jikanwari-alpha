import SwiftUI
import SwiftData
import UserNotifications

@main
struct 時間割アルファApp: App {

    let container: ModelContainer
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    init() {
        do {
            container = try ModelContainer(
                for: Course.self,
                    TimeSlot.self,
                    CourseNote.self,
                    NoteAttachment.self,
                    GeneralNote.self,
                    GeneralNoteAttachment.self,
                    Semester.self,
                    DepartureSchedule.self,
                    BelongingsItem.self
            )
        } catch {
            fatalError("SwiftData ModelContainer の初期化に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

// MARK: - AppDelegate (通知デリゲート)

final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // フォアグラウンドでも通知を表示
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // 通知アクション処理（アラームを止める）
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "STOP_ALARM" {
            NotificationCenter.default.post(name: .stopAlarm, object: nil)
        }
        completionHandler()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let stopAlarm = Notification.Name("com.sugawaraichirou.jikanwari.stopAlarm")
}
