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
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 8) {
                        ForEach(CourseColors.presets, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColorHex == hex ? 3 : 0)
                                        .padding(2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onTapGesture { selectedColorHex = hex }
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
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
