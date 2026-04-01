import SwiftUI

// MARK: - AddCourseView

struct AddCourseView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var subtitle: String = ""
    @State private var credits: Int = 2
    @State private var instructor: String = ""
    @State private var selectedColorHex: String = "#4A90D9"
    @State private var showColorPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("授業情報") {
                    HStack {
                        Text("授業名")
                        Spacer()
                        TextField("必須", text: $name)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("サブタイトル")
                        Spacer()
                        TextField("任意", text: $subtitle)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("担当教員")
                        Spacer()
                        TextField("任意", text: $instructor)
                            .multilineTextAlignment(.trailing)
                    }
                    Stepper("単位数: \(credits)", value: $credits, in: 1...8)
                }

                Section("表示色") {
                    // 6列→5列に変更（44pt タッチターゲットで収まる幅）
                    LazyVGrid(
                        columns: Array(repeating: .init(.flexible(), alignment: .center), count: 5),
                        spacing: 12
                    ) {
                        ForEach(CourseColors.presets, id: \.self) { hex in
                            let isSelected = selectedColorHex == hex
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                                    selectedColorHex = hex
                                }
                                HapticFeedback.light()
                            } label: {
                                ZStack {
                                    // 選択リング: 選択時に色付きリングが出現
                                    Circle()
                                        .stroke(Color(hex: hex), lineWidth: 2.5)
                                        .frame(width: 44, height: 44)
                                        .opacity(isSelected ? 1 : 0)
                                        .scaleEffect(isSelected ? 1 : 0.8)

                                    // 色円: 選択時に少し縮小してリングとの隙間を作る
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(
                                            width: isSelected ? 32 : 36,
                                            height: isSelected ? 32 : 36
                                        )

                                    // 選択チェックマーク
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(
                                                Color(hex: hex).isLight
                                                    ? Color.black.opacity(0.7)
                                                    : .white
                                            )
                                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                            }
                            .buttonStyle(.pressable(scale: 0.94))
                        }
                    }
                    .padding(.vertical, 4)

                    ColorPicker("カスタムカラー", selection: Binding(
                        get: { Color(hex: selectedColorHex) },
                        set: { selectedColorHex = $0.hexString }
                    ))
                }

                Section {
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: selectedColorHex))
                            .frame(height: 44)
                            .overlay(
                                Text(name.isEmpty ? "授業名" : name)
                                    .foregroundStyle(Color(hex: selectedColorHex).isLight ? .black : .white)
                                    .fontWeight(.semibold)
                            )
                    }
                } header: {
                    Text("プレビュー")
                }
            }
            .navigationTitle("授業を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        guard !name.isEmpty else { return }
                        _ = viewModel.addCourse(
                            name: name,
                            subtitle: subtitle,
                            credits: credits,
                            instructor: instructor,
                            colorHex: selectedColorHex,
                            context: modelContext
                        )
                        HapticFeedback.success()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
