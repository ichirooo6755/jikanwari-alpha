import Foundation
import SwiftData

// MARK: - DepartureSchedule
// 曜日ごとの出発スケジュール（授業の曜日に紐づく）

@Model
final class DepartureSchedule {
    var id: UUID
    var dayOfWeek: Int           // 0=月〜5=土
    var departureTime: Date      // 出発時刻
    var arrivalStationName: String  // 目的地の最寄り駅
    var homeStationName: String     // 自宅最寄り駅
    var transitPassLine: String     // 定期券路線
    var isEnabled: Bool
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var belongingsItems: [BelongingsItem]

    init(dayOfWeek: Int) {
        self.id = UUID()
        self.dayOfWeek = dayOfWeek
        // デフォルト出発時刻: 午前8時
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 8
        comps.minute = 0
        self.departureTime = Calendar.current.date(from: comps) ?? Date()
        self.arrivalStationName = ""
        self.homeStationName = ""
        self.transitPassLine = ""
        self.isEnabled = true
        self.updatedAt = Date()
        self.belongingsItems = []
    }

    var departureTimeComponents: DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: departureTime)
    }

    var wakeUpAlarmTime: Date {
        departureTime.addingTimeInterval(-40 * 60)  // 出発40分前
    }

    var eveningReminderTime: Date {
        // 前日の夜9時
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}

// MARK: - BelongingsItem
// 持ち物チェックリストアイテム

@Model
final class BelongingsItem {
    var id: UUID
    var name: String
    var isChecked: Bool
    var isDefault: Bool       // 毎日持つ必需品フラグ
    var sortOrder: Int
    var emoji: String

    @Relationship(inverse: \DepartureSchedule.belongingsItems)
    var schedule: DepartureSchedule?

    init(name: String, emoji: String = "📦", isDefault: Bool = false, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.isChecked = false
        self.isDefault = isDefault
        self.sortOrder = sortOrder
    }
}
