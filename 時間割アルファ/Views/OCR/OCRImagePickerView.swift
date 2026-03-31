import SwiftUI
import PhotosUI

// MARK: - OCRImagePickerView

struct OCRImagePickerView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var ocrVM = OCRViewModel()
    @State private var photosPickerItems: [PhotosPickerItem] = []
    @State private var showOCRSelection = false
    @State private var recognizedCourseName = ""
    @State private var recognizedCredits = 2
    @State private var recognizedInstructor = ""
    @State private var showAddConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = ocrVM.selectedImage {
                    // 画像が選択済み
                    VStack(spacing: 12) {
                        Button {
                            showOCRSelection = true
                        } label: {
                            ZStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                if ocrVM.isProcessing {
                                    ProgressView("認識中...")
                                        .padding()
                                        .background(.ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        Text("タップして選択範囲を指定してOCR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !ocrVM.recognizedText.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("認識結果")
                                .font(.headline)

                            Text(ocrVM.recognizedText)
                                .font(.body)
                                .padding()
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            // 授業名入力
                            HStack {
                                Text("授業名")
                                Spacer()
                                TextField("授業名", text: $recognizedCourseName)
                                    .multilineTextAlignment(.trailing)
                            }

                            HStack {
                                Text("担当教員")
                                Spacer()
                                TextField("任意", text: $recognizedInstructor)
                                    .multilineTextAlignment(.trailing)
                            }

                            Stepper("単位数: \(recognizedCredits)", value: $recognizedCredits, in: 1...8)

                            Button {
                                guard !recognizedCourseName.isEmpty else { return }
                                _ = viewModel.addCourse(
                                    name: recognizedCourseName,
                                    subtitle: "",
                                    credits: recognizedCredits,
                                    instructor: recognizedInstructor,
                                    colorHex: CourseColors.presets.randomElement() ?? "#4A90D9",
                                    context: modelContext
                                )
                                dismiss()
                            } label: {
                                Text("候補に追加")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(recognizedCourseName.isEmpty)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    // 画像未選択
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("画像から授業を読み取る")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("時間割の画像を選択して、授業名の部分を丸で囲うと文字起こしします")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        PhotosPicker(selection: $photosPickerItems, maxSelectionCount: 1, matching: .images) {
                            Label("画像を選択", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .onChange(of: photosPickerItems) { _, items in
                            items.first?.loadTransferable(type: Data.self) { result in
                                if case .success(let data) = result, let data, let img = UIImage(data: data) {
                                    DispatchQueue.main.async {
                                        ocrVM.selectedImage = img
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        Spacer()
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("OCRで授業追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                if ocrVM.selectedImage != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            ocrVM.reset()
                            photosPickerItems = []
                        } label: {
                            Text("リセット")
                        }
                    }
                }
            }
            .sheet(isPresented: $showOCRSelection) {
                if let image = ocrVM.selectedImage {
                    OCRSelectionView(image: image, ocrVM: ocrVM) { text in
                        recognizedCourseName = text
                    }
                }
            }
        }
    }
}
