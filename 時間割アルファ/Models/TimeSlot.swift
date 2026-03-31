import Foundation
import SwiftData

// MARK: - TimeSlot

@Model
final class TimeSlot {
    var day: Int           // 0=月, 1=火, 2=水, 3=木, 4=金, 5=土
    var period: Int        // 1〜5
    var priorityInSlot: Int  // 同コマ内の優先順位（小さい方が高優先）

    @Relationship(inverse: \Course.slots)
    var course: Course?

    init(day: Int, period: Int, priorityInSlot: Int = 0) {
        self.day = day
        self.period = period
        self.priorityInSlot = priorityInSlot
    }

    static let dayNames = ["月", "火", "水", "木", "金", "土"]

    var dayName: String {
        guard day >= 0, day < TimeSlot.dayNames.count else { return "" }
        return TimeSlot.dayNames[day]
    }
}
