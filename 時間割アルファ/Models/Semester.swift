import Foundation
import SwiftData

// MARK: - Semester

@Model
final class Semester {
    var id: UUID
    var name: String
    var isActive: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var courses: [Course]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isActive = false
        self.createdAt = Date()
        self.courses = []
    }
}
