import SwiftUI
import SwiftData

// MARK: - TimetableView

struct TimetableView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showAddCourse = false
    @State private var showBatchColorPicker = false
    @State private var batchColor = Color.blue
    @State private var showSemesterPicker = false
    @State private var draggedCourse: Course?

    @Query(sort: \Semester.createdAt)
    private var allSemesters: [Semester]

    private let periods = 1...5
    private let days = 0...5  // 月〜土

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー：モード切替 + アクションボタン
            headerBar

            if let semester = viewModel.selectedSemester {
                GeometryReader { geo in
                    let panelHeight = viewModel.isReferencePanelVisible && viewModel.isRegistrationMode
                        ? geo.size.height * 0.45
                        : 0

                    VStack(spacing: 0) {
                        // 時間割グリッド
                        timetableGrid
                            .frame(maxHeight: .infinity)

                        // 参照パネル（登録モードのみ）
                        if viewModel.isRegistrationMode && viewModel.isReferencePanelVisible {
                            ReferencePanelView(viewModel: viewModel)
                                .frame(height: max(panelHeight, 200))
                                .transition(.move(edge: .bottom))
                        }
                    }
                }

                // 授業候補リスト（登録モード）
                if viewModel.isRegistrationMode {
                    CourseCandidateListView(viewModel: viewModel)
                        .frame(maxHeight: 200)
                }
            } else {
                noSemesterView
            }
        }
        .sheet(isPresented: $showAddCourse) {
            AddCourseView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSemesterPicker) {
            SemesterPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showBatchColorPicker) {
            BatchColorPickerView(viewModel: viewModel)
        }
        .alert("履修確定", isPresented: $viewModel.showFinalizeConfirm) {
            Button("OK") {}
        } message: {
            Text("時間割を確定しました。")
        }
        .alert("時間割の競合があります", isPresented: $viewModel.showConflictAlert) {
            Button("このまま確定") {
                viewModel.showFinalizeConfirm = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            conflictMessage
        }
        .onAppear {
            viewModel.autoSelectCurrentSemester(allSemesters: allSemesters, context: modelContext)
        }
        .onChange(of: allSemesters) { _, new in
            // 学期が追加された直後に再チェック（まだ未選択の場合のみ）
            if viewModel.selectedSemester == nil {
                viewModel.autoSelectCurrentSemester(allSemesters: new, context: modelContext)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            // 学期選択
            Button {
                showSemesterPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                    Text(viewModel.selectedSemester?.name ?? "学期を選択")
                        .lineLimit(1)
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)

            Spacer()

            // 一括色変更ボタン
            if viewModel.isRegistrationMode && !viewModel.selectedCourses.isEmpty {
                Button {
                    showBatchColorPicker = true
                } label: {
                    Label("一括色変更", systemImage: "paintbrush.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }

            // 参照パネルトグル（登録モードのみ）
            if viewModel.isRegistrationMode {
                Button {
                    withAnimation { viewModel.isReferencePanelVisible.toggle() }
                } label: {
                    Image(systemName: viewModel.isReferencePanelVisible ? "rectangle.bottomhalf.filled" : "rectangle.bottomhalf")
                }
                .buttonStyle(.bordered)
            }

            // 履修確定ボタン（登録モード）
            if viewModel.isRegistrationMode {
                Button {
                    viewModel.finalizeRegistration(context: modelContext)
                } label: {
                    Label("確定", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            // モード切替
            ModeToggleView(viewModel: viewModel)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Timetable Grid

    private var timetableGrid: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 0) {
                // 列ヘッダー（曜日）
                dayHeaderRow

                // 各時限行
                ForEach(periods, id: \.self) { period in
                    periodRow(period: period)
                }
            }
            .padding(4)
        }
    }

    private var dayHeaderRow: some View {
        HStack(spacing: 2) {
            // 時限列ヘッダー
            Text("時限")
                .font(.caption2)
                .frame(width: 30, height: 30)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            ForEach(days, id: \.self) { day in
                Text(TimeSlot.dayNames[day])
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(
                        day == 5 ? Color(.systemRed).opacity(0.15) :
                        day == 6 ? Color(.systemBlue).opacity(0.15) :
                        Color(.systemGray5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func periodRow(period: Int) -> some View {
        HStack(spacing: 2) {
            // 時限番号
            Text("\(period)")
                .font(.caption2)
                .frame(width: 30)
                .frame(minHeight: 70)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            ForEach(days, id: \.self) { day in
                let coursesInSlot = viewModel.courses(day: day, period: period)

                TimetableCellView(
                    courses: coursesInSlot,
                    day: day,
                    period: period,
                    viewModel: viewModel
                )
                .frame(maxWidth: .infinity, minHeight: 70)
                .onDrop(of: [.text], isTargeted: nil) { providers in
                    handleDrop(providers: providers, day: day, period: period)
                }
            }
        }
    }

    // MARK: - Drag & Drop

    private func handleDrop(providers: [NSItemProvider], day: Int, period: Int) -> Bool {
        guard viewModel.isRegistrationMode else { return false }
        providers.first?.loadDataRepresentation(forTypeIdentifier: "public.text") { data, _ in
            guard let data, let idString = String(data: data, encoding: .utf8),
                  let id = UUID(uuidString: idString) else { return }
            DispatchQueue.main.async {
                guard let semester = viewModel.selectedSemester else { return }
                if let course = semester.courses.first(where: { $0.id == id }) {
                    // 既存スロットから移動 or 候補から配置
                    if let existingSlot = course.slots.first {
                        viewModel.moveCourse(course,
                                             fromDay: existingSlot.day, fromPeriod: existingSlot.period,
                                             toDay: day, toPeriod: period,
                                             context: modelContext)
                    } else {
                        viewModel.assignCourse(course, day: day, period: period, context: modelContext)
                    }
                }
            }
        }
        return true
    }

    // MARK: - Conflict Message

    private var conflictMessage: Text {
        let lines = viewModel.conflicts.map { conflict in
            let dayName = TimeSlot.dayNames[conflict.day]
            let courseNames = conflict.courses.map { $0.name }.joined(separator: "・")
            return "\(dayName)曜 \(conflict.period)限: \(courseNames)"
        }.joined(separator: "\n")
        return Text("以下のコマが重複しています:\n\(lines)\n\nこのまま確定しますか？")
    }

    // MARK: - No Semester

    private var noSemesterView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("学期を追加して始めましょう")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("学期を追加") {
                showSemesterPicker = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

// MARK: - ModeToggleView

struct ModeToggleView: View {
    @Bindable var viewModel: TimetableViewModel

    var body: some View {
        Picker("モード", selection: $viewModel.mode) {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Label(mode.displayName, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
    }
}
