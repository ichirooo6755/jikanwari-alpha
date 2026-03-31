import SwiftUI
import SwiftData

// MARK: - SemesterPickerView

struct SemesterPickerView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Semester.createdAt, order: .reverse)
    private var semesters: [Semester]

    @State private var showAddSemester = false
    @State private var newSemesterName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(semesters) { semester in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(semester.name)
                                .fontWeight(viewModel.selectedSemester?.id == semester.id ? .bold : .regular)
                            Text("\(semester.courses.count)科目")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.selectedSemester?.id == semester.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedSemester = semester
                        dismiss()
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteSemester(semesters[index], context: modelContext)
                    }
                }
            }
            .navigationTitle("学期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSemester = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("学期を追加", isPresented: $showAddSemester) {
                TextField("例: 2024年度 前期", text: $newSemesterName)
                Button("追加") {
                    guard !newSemesterName.isEmpty else { return }
                    _ = viewModel.addSemester(name: newSemesterName, context: modelContext)
                    newSemesterName = ""
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {
                    newSemesterName = ""
                }
            } message: {
                Text("学期名を入力してください")
            }
        }
    }
}
