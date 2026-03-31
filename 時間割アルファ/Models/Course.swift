import Foundation
import SwiftData

// MARK: - Enums

enum AttachmentType: String, Codable {
    case image
    case pdf
    case url
}

// MARK: - Course

@Model
final class Course {
    var id: UUID
    var name: String
    var subtitle: String
    var credits: Int
    var instructor: String
    var colorHex: String
    var isLocked: Bool
    var priority: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var slots: [TimeSlot]

    @Relationship(deleteRule: .cascade)
    var notes: [CourseNote]

    @Relationship(inverse: \Semester.courses)
    var semester: Semester?

    init(
        name: String,
        subtitle: String = "",
        credits: Int = 2,
        instructor: String = "",
        colorHex: String = "#4A90D9",
        priority: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.subtitle = subtitle
        self.credits = credits
        self.instructor = instructor
        self.colorHex = colorHex
        self.isLocked = false
        self.priority = priority
        self.createdAt = Date()
        self.slots = []
        self.notes = []
    }
}
