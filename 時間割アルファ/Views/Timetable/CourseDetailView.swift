import SwiftUI
import SwiftData
import PhotosUI

// MARK: - CourseDetailView

struct CourseDetailView: View {
    @Bindable var course: Course
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var noteToDelete: CourseNote?

    var body: some View {
        List {
            courseInfoSection
            slotSection
            notesSection
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isRegistrationMode {
                Button {
                    try? modelContext.save()
                } label: {
                    Text("変更を保存")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var courseInfoSection: some View {
        Section("授業情報") {
            if viewModel.isRegistrationMode {
                editableFields
            } else {
                readonlyFields
            }
        }
    }

    @ViewBuilder
    private var editableFields: some View {
        HStack {
            Text("授業名").foregroundStyle(.secondary)
            Spacer()
            TextField("授業名", text: $course.name).multilineTextAlignment(.trailing)
        }
        HStack {
            Text("サブタイトル").foregroundStyle(.secondary)
            Spacer()
            TextField("任意", text: $course.subtitle).multilineTextAlignment(.trailing)
        }
        HStack {
            Text("担当教員").foregroundStyle(.secondary)
            Spacer()
            TextField("教員名", text: $course.instructor).multilineTextAlignment(.trailing)
        }
        Stepper("単位数: \(course.credits)", value: $course.credits, in: 1...8)
        ColorPicker("授業カラー", selection: Binding(
            get: { Color(hex: course.colorHex) },
            set: { course.colorHex = $0.hexString }
        ))
        Toggle("ロック（移動禁止）", isOn: $course.isLocked)
    }

    @ViewBuilder
    private var readonlyFields: some View {
        LabeledContent("授業名", value: course.name)
        if !course.subtitle.isEmpty {
            LabeledContent("サブタイトル", value: course.subtitle)
        }
        LabeledContent("担当教員", value: course.instructor.isEmpty ? "未設定" : course.instructor)
        LabeledContent("単位数", value: "\(course.credits)単位")
    }

    private var sortedSlots: [TimeSlot] {
        course.slots.sorted { a, b in
            if a.day != b.day { return a.day < b.day }
            return a.period < b.period
        }
    }

    @ViewBuilder
    private var slotSection: some View {
        if !sortedSlots.isEmpty {
            Section("配置コマ") {
                ForEach(sortedSlots) { slot in
                    HStack {
                        Text("\(slot.dayName)曜 \(slot.period)限")
                        Spacer()
                        if course.isLocked {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    if viewModel.isRegistrationMode { deleteSlots(at: offsets) }
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        Section {
            ForEach(course.notes) { note in
                NoteRowView(note: note, isEditable: true, onDelete: {
                    removeNote(note)
                })
            }
            .onDelete { indexSet in
                for index in indexSet { removeNote(course.notes[index]) }
            }
            Button { addNote() } label: {
                Label("メモを追加", systemImage: "plus.circle")
            }
        } header: {
            Text("メモ")
        }
    }

    private func addNote() {
        let note = CourseNote()
        modelContext.insert(note)
        course.notes.append(note)
        try? modelContext.save()
    }

    private func removeNote(_ note: CourseNote) {
        course.notes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        try? modelContext.save()
    }

    private func deleteSlots(at offsets: IndexSet) {
        let sorted = course.slots.sorted { a, b in
            if a.day != b.day { return a.day < b.day }
            return a.period < b.period
        }
        for index in offsets {
            let slot = sorted[index]
            course.slots.removeAll { $0.id == slot.id }
            modelContext.delete(slot)
        }
        try? modelContext.save()
    }
}

// MARK: - NoteRowView

struct NoteRowView: View {
    @Bindable var note: CourseNote
    var isEditable: Bool
    var onDelete: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var photosPickerItems: [PhotosPickerItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditable {
                TextEditor(text: $note.text)
                    .frame(minHeight: 80)
                    .onChange(of: note.text) { _, _ in
                        note.updatedAt = Date()
                    }
            } else {
                Text(note.text).font(.body)
            }

            if !note.attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(note.attachments) { att in
                            AttachmentThumbnailView(attachment: att)
                        }
                    }
                }
                .frame(height: 80)
            }

            if isEditable {
                HStack {
                    PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 5, matching: .images) {
                        Label("画像", systemImage: "photo").font(.caption)
                    }
                    .onChange(of: photosPickerItems) { _, items in
                        loadPhotos(from: items)
                    }
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash").font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadPhotos(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data {
                    DispatchQueue.main.async {
                        let att = NoteAttachment(type: .image, data: data,
                                                 filename: "image_\(UUID().uuidString).jpg")
                        modelContext.insert(att)
                        note.attachments.append(att)
                        try? modelContext.save()
                    }
                }
            }
        }
    }
}

// MARK: - AttachmentThumbnailView

struct AttachmentThumbnailView: View {
    let attachment: NoteAttachment

    var body: some View {
        Group {
            switch attachment.type {
            case .image:
                if let data = attachment.data, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    imagePlaceholder
                }
            case .pdf:
                pdfThumbnail
            case .url:
                urlThumbnail
            }
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(width: 70, height: 70)
    }

    private var pdfThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.red.opacity(0.15))
            .frame(width: 70, height: 70)
            .overlay(
                VStack {
                    Image(systemName: "doc.fill").foregroundStyle(.red)
                    Text("PDF").font(.caption2)
                }
            )
    }

    private var urlThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.blue.opacity(0.15))
            .frame(width: 70, height: 70)
            .overlay(
                VStack {
                    Image(systemName: "link").foregroundStyle(.blue)
                    Text(attachment.filename).font(.caption2).lineLimit(2)
                }
                .padding(4)
            )
    }
}
