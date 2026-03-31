import Foundation
import SwiftData

// MARK: - CourseNote

@Model
final class CourseNote {
    var id: UUID
    var text: String
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var attachments: [NoteAttachment]

    @Relationship(inverse: \Course.notes)
    var course: Course?

    init(text: String = "") {
        self.id = UUID()
        self.text = text
        self.updatedAt = Date()
        self.attachments = []
    }
}

// MARK: - NoteAttachment

@Model
final class NoteAttachment {
    var id: UUID
    var type: AttachmentType
    var data: Data?
    var urlString: String?
    var filename: String
    var createdAt: Date

    @Relationship(inverse: \CourseNote.attachments)
    var note: CourseNote?

    init(type: AttachmentType, data: Data? = nil, urlString: String? = nil, filename: String) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.urlString = urlString
        self.filename = filename
        self.createdAt = Date()
    }
}
