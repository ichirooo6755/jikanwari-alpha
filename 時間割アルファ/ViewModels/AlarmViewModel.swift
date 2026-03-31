import Foundation
import UserNotifications
import AVFoundation
import SwiftUI
import SwiftData

// MARK: - AlarmViewModel
// 前日夜9時リマインド・出発40分前アラーム管理

@MainActor
@Observable
final class AlarmViewModel {

    // アラーム状態
    var isAlarmFiring: Bool = false
    var firingSchedule: DepartureSchedule?
    var permissionGranted: Bool = false
    var audioError: String?

    private var audioPlayer: AVAudioPlayer?
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert]
            )
            permissionGranted = granted
        } catch {
            permissionGranted = false
        }
    }

    func checkPermission() async {
        let settings = await notificationCenter.notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    // MARK: - Schedule Notifications

    /// 全スケジュールの通知を再登録
    func rescheduleAllNotifications(schedules: [DepartureSchedule]) async {
        // 既存の全通知を削除
        notificationCenter.removeAllPendingNotificationRequests()

        for schedule in schedules where schedule.isEnabled {
            await scheduleEveningReminder(for: schedule)
            await scheduleWakeUpAlarm(for: schedule)
        }
    }

    /// 前日夜9時リマインド通知
    private func scheduleEveningReminder(for schedule: DepartureSchedule) async {
        let content = UNMutableNotificationContent()
        content.title = "明日の準備を確認しよう"
        let dayName = TimeSlot.dayNames[schedule.dayOfWeek]
        let timeStr = schedule.departureTime.formatted(date: .omitted, time: .shortened)
        content.body = "\(dayName)曜日の出発は \(timeStr) です。持ち物の確認を忘れずに！"
        content.sound = .default
        content.categoryIdentifier = "EVENING_REMINDER"

        // 前日 = dayOfWeek - 1（日曜=0を月曜前日として扱う）
        let prevDay = schedule.dayOfWeek == 0 ? 7 : schedule.dayOfWeek  // 月前日=日曜(1の前=7)
        // UNCalendarNotificationTrigger の weekday: 1=日曜, 2=月曜, ..., 7=土曜
        let weekdayForTrigger = (prevDay % 7) + 1  // 0=月→prevDay=7→trigger=1(日)

        var triggerComps = DateComponents()
        triggerComps.weekday = weekdayForTrigger
        triggerComps.hour = 21
        triggerComps.minute = 0
        triggerComps.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "evening_reminder_\(schedule.dayOfWeek)",
            content: content,
            trigger: trigger
        )
        try? await notificationCenter.add(request)
    }

    /// 出発40分前アラーム通知
    private func scheduleWakeUpAlarm(for schedule: DepartureSchedule) async {
        let content = UNMutableNotificationContent()
        content.title = "出発まで40分！"
        let timeStr = schedule.departureTime.formatted(date: .omitted, time: .shortened)
        content.body = "\(timeStr) 出発に向けて準備を始めましょう"
        content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        content.interruptionLevel = .critical
        content.categoryIdentifier = "DEPARTURE_ALARM"

        let alarmComps = Calendar.current.dateComponents([.hour, .minute], from: schedule.wakeUpAlarmTime)
        // 曜日: 1=日, 2=月, ..., 7=土
        let weekday = schedule.dayOfWeek + 2  // 0=月→2, 5=土→7

        var triggerComps = DateComponents()
        triggerComps.weekday = weekday
        triggerComps.hour = alarmComps.hour
        triggerComps.minute = alarmComps.minute
        triggerComps.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: true)
        let request = UNNotificationRequest(
            identifier: "departure_alarm_\(schedule.dayOfWeek)",
            content: content,
            trigger: trigger
        )
        try? await notificationCenter.add(request)
    }

    // MARK: - In-App Alarm (大音量・止めるまで鳴り続ける)

    func startAlarm(for schedule: DepartureSchedule) {
        firingSchedule = schedule
        isAlarmFiring = true
        playAlarmSound()
    }

    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        isAlarmFiring = false
        firingSchedule = nil
    }

    private func playAlarmSound() {
        do {
            // AVAudioSession: 消音スイッチを無視して最大音量で再生
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.duckOthers])
            try session.setActive(true)
            // ベルサウンド
            if let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
            } else {
                // システムサウンドにフォールバック
                let systemSoundURL = URL(fileURLWithPath: "/System/Library/Audio/UISounds/alarm.caf")
                audioPlayer = try? AVAudioPlayer(contentsOf: systemSoundURL)
            }
            audioPlayer?.numberOfLoops = -1  // 無限ループ
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        } catch {
            audioError = error.localizedDescription
        }
    }

    // MARK: - Notification Categories

    func registerNotificationCategories() {
        let stopAction = UNNotificationAction(
            identifier: "STOP_ALARM",
            title: "アラームを止める",
            options: [.foreground]
        )
        let alarmCategory = UNNotificationCategory(
            identifier: "DEPARTURE_ALARM",
            actions: [stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let reminderCategory = UNNotificationCategory(
            identifier: "EVENING_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([alarmCategory, reminderCategory])
    }
}
