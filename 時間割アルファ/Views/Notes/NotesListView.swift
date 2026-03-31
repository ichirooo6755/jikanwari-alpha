import SwiftUI
import SwiftData

// MARK: - NotesListView (iOS純正メモ風)

struct NotesListView: View {
    @State private var notesVM = NotesViewModel()
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \GeneralNote.updatedAt, order: .reverse)
    private var allNotes: [GeneralNote]

    @State private var showDeleteConfirm = false
    @State private var noteToDelete: GeneralNote?

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            if let note = notesVM.selectedNote {
                NoteDetailView(note: note)
            } else {
                ContentUnavailableView(
                    "メモを選択",
                    systemImage: "note.text",
                    description: Text("左のリストからメモを選択するか、新規作成してください")
                )
            }
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // フォルダフィルター
            if !notesVM.folders(from: allNotes).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        filterChip(label: "すべて", isSelected: notesVM.selectedFolder == nil) {
                            notesVM.selectedFolder = nil
                        }
                        ForEach(notesVM.folders(from: allNotes), id: \.self) { folder in
                            filterChip(label: folder, isSelected: notesVM.selectedFolder == folder) {
                                notesVM.selectedFolder = folder
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                Divider()
            }

            let filtered = notesVM.filteredNotes(allNotes)
            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("メモなし")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(selection: Binding(
                    get: { notesVM.selectedNote?.id },
                    set: { id in
                        notesVM.selectedNote = allNotes.first { $0.id == id }
                    }
                )) {
                    // ピン留め
                    let pinned = filtered.filter { $0.isPinned }
                    if !pinned.isEmpty {
                        Section("ピン留め") {
                            ForEach(pinned) { note in
                                NoteRowItem(note: note, notesVM: notesVM)
                                    .tag(note.id)
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            notesVM.togglePin(note, context: modelContext)
                                        } label: {
                                            Label("ピン解除", systemImage: "pin.slash")
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            notesVM.deleteNote(note, context: modelContext)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }

                    // 通常
                    let normal = filtered.filter { !$0.isPinned }
                    if !normal.isEmpty {
                        Section(pinned.isEmpty ? "" : "メモ") {
                            ForEach(normal) { note in
                                NoteRowItem(note: note, notesVM: notesVM)
                                    .tag(note.id)
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            notesVM.togglePin(note, context: modelContext)
                                        } label: {
                                            Label("ピン留め", systemImage: "pin")
                                        }
                                        .tint(.orange)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            notesVM.deleteNote(note, context: modelContext)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .searchable(text: $notesVM.searchText, prompt: "メモを検索")
        .navigationTitle("メモ")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let note = notesVM.addNote(context: modelContext)
                    notesVM.selectedNote = note
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.yellow : Color(.systemGray5))
                .foregroundStyle(isSelected ? Color.black : Color.primary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - NoteRowItem

struct NoteRowItem: View {
    let note: GeneralNote
    let notesVM: NotesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            HStack {
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            notesVM.selectedNote = note
        }
    }
}
