import SwiftUI
import PhotosUI

// MARK: - NoteDetailView (iOS純正メモ風)

struct NoteDetailView: View {
    @Bindable var note: GeneralNote
    @Environment(\.modelContext) private var modelContext

    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var showFilePicker = false
    @State private var showFolderEditor = false
    @State private var newFolderName = ""
    @FocusState private var isBodyFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 本文エディタ
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // タイトル（最初の行が自動タイトル）
                    TextEditor(text: $note.body)
                        .font(.body)
                        .frame(minHeight: 400)
                        .focused($isBodyFocused)
                        .onChange(of: note.body) { _, _ in
                            note.updatedAt = Date()
                        }

                    // 添付ファイル一覧
                    if !note.attachments.isEmpty {
                        Divider()
                        Text("添付ファイル")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: .init(.flexible(maximum: 120)), count: 4), spacing: 8) {
                            ForEach(note.attachments) { attachment in
                                GeneralAttachmentView(attachment: attachment) {
                                    note.attachments.removeAll { $0.id == attachment.id }
                                    modelContext.delete(attachment)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // ツールバー
            HStack(spacing: 20) {
                // 画像添付
                PhotosPicker(selection: $photosPickerItems, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title3)
                }
                .onChange(of: photosPickerItems) { _, items in
                    for item in items {
                        item.loadTransferable(type: Data.self) { result in
                            if case .success(let data) = result, let data {
                                DispatchQueue.main.async {
                                    let att = GeneralNoteAttachment(
                                        type: .image,
                                        data: data,
                                        filename: "image_\(UUID().uuidString).jpg"
                                    )
                                    modelContext.insert(att)
                                    note.attachments.append(att)
                                    note.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                    photosPickerItems = []
                }

                // PDFファイル添付
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                }

                Spacer()

                // フォルダ
                Button {
                    newFolderName = note.folderName
                    showFolderEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                        if !note.folderName.isEmpty {
                            Text(note.folderName)
                                .font(.caption)
                        }
                    }
                    .font(.title3)
                }

                // 日時表示
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // キーボード閉じる
                Button {
                    isBodyFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        newFolderName = note.folderName
                        showFolderEditor = true
                    } label: {
                        Label("フォルダを変更", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                if let data = try? Data(contentsOf: url) {
                    let att = GeneralNoteAttachment(
                        type: .pdf,
                        data: data,
                        filename: url.lastPathComponent
                    )
                    modelContext.insert(att)
                    note.attachments.append(att)
                    note.updatedAt = Date()
                    try? modelContext.save()
                }
            }
        }
        .alert("フォルダ", isPresented: $showFolderEditor) {
            TextField("フォルダ名", text: $newFolderName)
            Button("保存") {
                note.folderName = newFolderName
                note.updatedAt = Date()
                try? modelContext.save()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("このメモのフォルダを設定します（空欄でフォルダなし）")
        }
        .onAppear {
            isBodyFocused = true
        }
    }
}

// MARK: - GeneralAttachmentView

struct GeneralAttachmentView: View {
    let attachment: GeneralNoteAttachment
    let onDelete: () -> Void

    @State private var showPDF = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailContent
                .onTapGesture {
                    if attachment.type == .pdf { showPDF = true }
                }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .font(.caption)
            }
            .offset(x: 4, y: -4)
        }
        .sheet(isPresented: $showPDF) {
            if let data = attachment.data {
                PDFDataViewerRepresentable(data: data)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        switch attachment.type {
        case .image:
            if let data = attachment.data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        case .pdf:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.red)
                        Text(attachment.filename)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .padding(4)
                )
        case .url:
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    VStack {
                        Image(systemName: "link")
                            .foregroundStyle(.blue)
                        Text(attachment.filename).font(.caption2)
                    }
                )
        }
    }
}
