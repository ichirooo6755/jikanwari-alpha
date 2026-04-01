import SwiftUI
import SwiftData

// MARK: - SemesterPickerView

struct SemesterPickerView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Semester.createdAt, order: .reverse)
    private var semesters: [Semester]

    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(semesters) { semester in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(semester.name)
                                .fontWeight(viewModel.selectedSemester?.id == semester.id ? .bold : .regular)
                            Text("\(semester.courses.count)科目")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.selectedSemester?.id == semester.id {
                            Image(systemName: "checkmark.circle.fill")
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
            .navigationTitle("学期を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSemesterSheet(viewModel: viewModel, existingSemesters: semesters) {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - AddSemesterSheet

struct AddSemesterSheet: View {
    @Bindable var viewModel: TimetableViewModel
    let existingSemesters: [Semester]
    let onAdded: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let currentYear = Calendar.current.component(.year, from: Date())
    private let currentMonth = Calendar.current.component(.month, from: Date())

    // 選択肢：現在年の前後2年
    private var yearOptions: [Int] {
        (currentYear - 1 ... currentYear + 2).map { $0 }
    }

    @State private var selectedYear: Int
    @State private var selectedTerm: Term

    enum Term: String, CaseIterable {
        case spring = "春学期"
        case fall   = "秋学期"
    }

    init(viewModel: TimetableViewModel, existingSemesters: [Semester], onAdded: @escaping () -> Void) {
        self.viewModel = viewModel
        self.existingSemesters = existingSemesters
        self.onAdded = onAdded

        let year = Calendar.current.component(.year, from: Date())
        let month = Calendar.current.component(.month, from: Date())
        _selectedYear = State(initialValue: year)
        _selectedTerm = State(initialValue: month <= 5 ? .spring : .fall)
    }

    private var semesterName: String {
        "\(selectedYear)年 \(selectedTerm.rawValue)"
    }

    private var alreadyExists: Bool {
        existingSemesters.contains { $0.name == semesterName }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("年度") {
                    Picker("年", selection: $selectedYear) {
                        ForEach(yearOptions, id: \.self) { year in
                            Text("\(year)年").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                Section("学期") {
                    Picker("学期", selection: $selectedTerm) {
                        ForEach(Term.allCases, id: \.self) { term in
                            Text(term.rawValue).tag(term)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(semesterName)
                                .font(.title2)
                                .fontWeight(.bold)
                            if alreadyExists {
                                Label("すでに存在します", systemImage: "exclamationmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("プレビュー")
                }
            }
            .navigationTitle("学期を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        _ = viewModel.addSemester(name: semesterName, context: modelContext)
                        dismiss()
                        onAdded()
                    }
                    .disabled(alreadyExists)
                }
            }
        }
    }
}
