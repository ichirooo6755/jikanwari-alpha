import Foundation
import SwiftData

// MARK: - GeneralNote

@Model
final class GeneralNote {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var folderName: String

    @Relationship(deleteRule: .cascade)
    var attachments: [GeneralNoteAttachment]

    init(title: String = "", body: String = "", folderName: String = "") {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.folderName = folderName
        self.attachments = []
    }

    var displayTitle: String {
        if !title.isEmpty { return title }
        let firstLine = body.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "新規メモ" : firstLine
    }

    var preview: String {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.count > 1 {
            return lines.dropFirst().joined(separator: " ").prefix(100).description
        }
        return ""
    }
}

// MARK: - GeneralNoteAttachment

@Model
final class GeneralNoteAttachment {
    var id: UUID
    var type: AttachmentType
    var data: Data?
    var urlString: String?
    var filename: String
    var createdAt: Date

    @Relationship(inverse: \GeneralNote.attachments)
    var note: GeneralNote?

    init(type: AttachmentType, data: Data? = nil, urlString: String? = nil, filename: String) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.urlString = urlString
        self.filename = filename
        self.createdAt = Date()
    }
}
