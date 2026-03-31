import Foundation
import SwiftUI
import SwiftData

// MARK: - NotesViewModel

@Observable
final class NotesViewModel {

    var searchText: String = ""
    var selectedFolder: String? = nil
    var selectedNote: GeneralNote?

    func filteredNotes(_ notes: [GeneralNote]) -> [GeneralNote] {
        var filtered = notes
        if let folder = selectedFolder {
            filtered = filtered.filter { $0.folderName == folder }
        }
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.body.localizedCaseInsensitiveContains(searchText)
            }
        }
        // ピン留め→更新日時 順でソート
        return filtered.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    func folders(from notes: [GeneralNote]) -> [String] {
        let names = notes.compactMap { $0.folderName.isEmpty ? nil : $0.folderName }
        return Array(Set(names)).sorted()
    }

    func addNote(context: ModelContext) -> GeneralNote {
        let note = GeneralNote()
        context.insert(note)
        try? context.save()
        selectedNote = note
        return note
    }

    func deleteNote(_ note: GeneralNote, context: ModelContext) {
        if selectedNote?.id == note.id { selectedNote = nil }
        context.delete(note)
        try? context.save()
    }

    func togglePin(_ note: GeneralNote, context: ModelContext) {
        note.isPinned.toggle()
        note.updatedAt = Date()
        try? context.save()
    }
}
