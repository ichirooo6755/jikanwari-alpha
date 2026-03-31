import SwiftUI

// MARK: - BatchColorPickerView

struct BatchColorPickerView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHex: String = "#4A90D9"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 選択中の授業
                VStack(alignment: .leading, spacing: 8) {
                    Text("選択中の授業")
                        .font(.headline)
                    let selected = viewModel.allCourses.filter { viewModel.selectedCourses.contains($0.id) }
                    ForEach(selected) { course in
                        HStack {
                            Circle()
                                .fill(Color(hex: course.colorHex))
                                .frame(width: 12, height: 12)
                            Text(course.name)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // プリセット色
                VStack(alignment: .leading, spacing: 12) {
                    Text("色を選択")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 12) {
                        ForEach(CourseColors.presets, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedHex == hex ? 3 : 0)
                                        .padding(2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onTapGesture { selectedHex = hex }
                        }
                    }
                    .padding(.horizontal)

                    HStack {
                        ColorPicker("カスタムカラー", selection: Binding(
                            get: { Color(hex: selectedHex) },
                            set: { selectedHex = $0.hexString }
                        ))
                        .padding(.horizontal)
                    }
                }

                Spacer()

                // プレビュー
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: selectedHex))
                    .frame(height: 60)
                    .overlay(
                        Text("プレビュー")
                            .foregroundStyle(Color(hex: selectedHex).isLight ? .black : .white)
                            .fontWeight(.semibold)
                    )
                    .padding(.horizontal)

                Button {
                    viewModel.setBatchColor(selectedHex, context: modelContext)
                    dismiss()
                } label: {
                    Text("選択した\(viewModel.selectedCourses.count)科目に適用")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: selectedHex))
                        .foregroundStyle(Color(hex: selectedHex).isLight ? .black : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("一括色変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        viewModel.selectedCourses.removeAll()
                        dismiss()
                    }
                }
            }
        }
    }
}
