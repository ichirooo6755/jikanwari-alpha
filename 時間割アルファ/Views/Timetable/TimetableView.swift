import SwiftUI
import SwiftData

// MARK: - TimetableView

struct TimetableView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showSemesterPicker = false
    @State private var showBatchColorPicker = false
    @State private var showCandidateSheet = false
    @State private var showReferencePanel = false

    @Query(sort: \Semester.createdAt)
    private var allSemesters: [Semester]

    private let periods = 1...5
    private let days = 0...5

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                compactHeader(geo: geo)

                if viewModel.selectedSemester != nil {
                    // グリッドが残り全スペースを使う
                    timetableGrid(geo: geo)
                        .frame(maxHeight: .infinity)

                    // 参照パネル（登録モード・展開時のみ）
                    if viewModel.isRegistrationMode && showReferencePanel {
                        ReferencePanelView(viewModel: viewModel)
                            .frame(height: geo.size.height * 0.42)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                )
                            )
                    }
                } else {
                    noSemesterView
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        // 候補リスト・授業追加（ボトムシート）
        .sheet(isPresented: $showCandidateSheet) {
            CourseCandidateSheetView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSemesterPicker) {
            SemesterPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showBatchColorPicker) {
            BatchColorPickerView(viewModel: viewModel)
        }
        .alert("履修確定", isPresented: $viewModel.showFinalizeConfirm) {
            Button("OK") {
                HapticFeedback.success()
                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                    viewModel.mode = .reference
                }
            }
        } message: {
            Text("時間割を確定しました。参照モードに切り替わります。")
        }
        .alert("時間割の競合があります", isPresented: $viewModel.showConflictAlert) {
            Button("このまま確定") { viewModel.showFinalizeConfirm = true }
            Button("キャンセル", role: .cancel) {}
        } message: {
            conflictMessage
        }
        .onAppear {
            viewModel.autoSelectCurrentSemester(allSemesters: allSemesters, context: modelContext)
        }
        .onChange(of: allSemesters) { _, new in
            if viewModel.selectedSemester == nil {
                viewModel.autoSelectCurrentSemester(allSemesters: new, context: modelContext)
            }
        }
    }

    // MARK: - Compact Header

    private func compactHeader(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // 上段: 学期名 + モード切替セグメント
            HStack(spacing: 10) {
                // 学期名（左）
                Button {
                    showSemesterPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.selectedSemester?.name ?? "学期未選択")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.pressable)

                Spacer()

                // モード切替: 明確なセグメントコントロール
                modeSegmentedControl
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .padding(.top, geo.safeAreaInsets.top)

            // 下段: モード別アクションバー（トランジション付き）
            if viewModel.isRegistrationMode {
                registrationActionBar
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                referenceActionBar
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity
                    ))
            }

            Divider()
        }
        .background(Color(.systemBackground).opacity(0.97))
    }

    // MARK: - Mode Segmented Control

    private var modeSegmentedControl: some View {
        HStack(spacing: 0) {
            modeButton(mode: .registration, label: "登録", icon: "pencil")
            modeButton(mode: .reference, label: "参照", icon: "eye")
        }
        .background(
            Capsule().fill(Color(.systemGray5))
        )
    }

    private func modeButton(mode: AppMode, label: String, icon: String) -> some View {
        let isActive = viewModel.mode == mode
        return Button {
            guard viewModel.mode != mode else { return }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                viewModel.mode = mode
            }
            HapticFeedback.medium()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                isActive
                    ? Capsule().fill(mode == .registration ? Color.blue : Color(.systemGray3))
                    : Capsule().fill(Color.clear)
            )
            .foregroundStyle(isActive ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    // MARK: - Registration Action Bar

    private var registrationActionBar: some View {
        HStack(spacing: 12) {
            // 一括色変更
            if !viewModel.selectedCourses.isEmpty {
                Button {
                    showBatchColorPicker = true
                } label: {
                    Label("色変更", systemImage: "paintbrush.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressable)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // 参照パネル切替
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.80)) {
                    showReferencePanel.toggle()
                }
                HapticFeedback.light()
            } label: {
                Label(showReferencePanel ? "パネル閉" : "参照パネル",
                      systemImage: showReferencePanel ? "rectangle.bottomhalf.filled" : "rectangle.bottomhalf")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.pressable)

            Spacer()

            // 履修確定ボタン — 大きく目立たせる
            Button {
                HapticFeedback.rigid()
                viewModel.finalizeRegistration(context: modelContext)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                    Text("履修確定")
                        .font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Reference Action Bar

    private var referenceActionBar: some View {
        HStack(spacing: 12) {
            // 参照モードラベル
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption)
                Text("閲覧中 — メモは編集可能")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Spacer()

            // 共有ボタン
            if let semester = viewModel.selectedSemester {
                TimetableShareButton(semester: semester, viewModel: viewModel)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Timetable Grid (画面を満たす)

    private func timetableGrid(geo: GeometryProxy) -> some View {
        // 利用可能な高さからセルの高さを計算
        let headerH: CGFloat = 28   // 曜日ヘッダー行
        let periodColW: CGFloat = 22 // 時限番号列の幅
        let spacing: CGFloat = 1

        // 安全領域を除いた高さを5コマで割る
        let availableH = geo.size.height
            - headerH
            - (viewModel.isRegistrationMode && showReferencePanel ? geo.size.height * 0.42 : 0)
            - 76  // compactHeader概算（2段ヘッダー）
            - geo.safeAreaInsets.bottom
        let cellH = max(44, (availableH - CGFloat(periods.count) * spacing) / CGFloat(periods.count))

        let availableW = geo.size.width - periodColW - CGFloat(days.count) * spacing
        let cellW = availableW / CGFloat(days.count)

        // 今日の曜日インデックス（月=0 〜 土=5、範囲外なら -1）
        let todayIndex: Int = {
            let weekday = Calendar.current.component(.weekday, from: Date())
            // weekday: 1=日, 2=月...7=土 → アプリ: 0=月...5=土
            let idx = weekday - 2
            return (0...5).contains(idx) ? idx : -1
        }()

        return VStack(spacing: spacing) {
            // 曜日ヘッダー
            HStack(spacing: spacing) {
                Color.clear.frame(width: periodColW, height: headerH)
                ForEach(days, id: \.self) { day in
                    Text(TimeSlot.dayNames[day])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            day == 5 ? Color.red :
                            day == todayIndex ? Color.blue :
                            Color.primary
                        )
                        .frame(width: cellW, height: headerH)
                        .background(
                            day == 5 ? Color.red.opacity(0.12) :
                            day == todayIndex ? Color.blue.opacity(0.10) :
                            Color(.systemGray6)
                        )
                }
            }

            // 時限行
            ForEach(periods, id: \.self) { period in
                HStack(spacing: spacing) {
                    // 時限番号
                    Text("\(period)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: periodColW, height: cellH)
                        .background(Color(.systemGray6))

                    // 各曜日セル
                    ForEach(days, id: \.self) { day in
                        let courses = viewModel.courses(day: day, period: period)
                        TimetableCellView(
                            courses: courses,
                            day: day,
                            period: period,
                            viewModel: viewModel
                        )
                        .frame(width: cellW, height: cellH)
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            handleDrop(providers: providers, day: day, period: period)
                        }
                    }
                }
            }
        }
        // 登録モード: FABボタン（候補リストを開く）
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isRegistrationMode {
                Button {
                    showCandidateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.blue)
                        .clipShape(Circle())
                        // カラー影: 青い光彩でボタンが浮いて見える
                        .shadow(color: Color.blue.opacity(0.35), radius: 12, x: 0, y: 6)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(FABButtonStyle())
                .padding(.trailing, 16)
                .padding(.bottom, geo.safeAreaInsets.bottom + 8)
                // spring 登場: scale(0.7) + opacity から入場
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.7, anchor: .bottomTrailing)
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: .bottomTrailing)
                            .combined(with: .opacity)
                    )
                )
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
        let lines = viewModel.conflicts.map { c in
            "\(TimeSlot.dayNames[c.day])曜 \(c.period)限: \(c.courses.map(\.name).joined(separator: "・"))"
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
            Text("学期を選択してください")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("学期を選択・作成") { showSemesterPicker = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

// MARK: - CourseCandidateSheetView（ボトムシート版）

struct CourseCandidateSheetView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showAddCourse = false
    @State private var showOCR = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("授業名・教員名で検索", text: $viewModel.searchText)
                    if !viewModel.searchText.isEmpty {
                        Button { viewModel.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if viewModel.filteredCandidates.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text(viewModel.searchText.isEmpty ? "候補がありません" : "見つかりません")
                            .foregroundStyle(.secondary)
                        if viewModel.searchText.isEmpty {
                            Button { showAddCourse = true } label: {
                                Label("授業を追加", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(viewModel.filteredCandidates) { course in
                            CandidateListRow(course: course, viewModel: viewModel)
                                .onDrag { NSItemProvider(object: course.id.uuidString as NSString) }
                        }
                        .onDelete { idx in
                            for i in idx { viewModel.deleteCourse(viewModel.filteredCandidates[i], context: modelContext) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("授業候補")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button { showOCR = true } label: {
                            Label("OCR", systemImage: "doc.viewfinder")
                        }
                        Button { showAddCourse = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddCourse) { AddCourseView(viewModel: viewModel) }
        .sheet(isPresented: $showOCR) { OCRImagePickerView(viewModel: viewModel) }
    }
}

// MARK: - CandidateListRow

struct CandidateListRow: View {
    let course: Course
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showDetail = false

    var body: some View {
        let isSelected = viewModel.selectedCourses.contains(course.id)

        Button {
            viewModel.toggleCourseSelection(course.id)
            HapticFeedback.light()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: course.colorHex))
                    .frame(width: 6, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        if !course.instructor.isEmpty {
                            Text(course.instructor).font(.caption).foregroundStyle(.secondary)
                        }
                        Text("\(course.credits)単位").font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 選択状態: チェックマーク ↔ ドラッグハンドル
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .contextMenu {
            Button { showDetail = true } label: { Label("詳細・メモ", systemImage: "info.circle") }
            Button(role: .destructive) {
                viewModel.deleteCourse(course, context: modelContext)
            } label: { Label("削除", systemImage: "trash") }
        }
        .sheet(isPresented: $showDetail) {
            NavigationStack { CourseDetailView(course: course, viewModel: viewModel) }
        }
    }
}

// MARK: - ModeToggleView (後方互換)

struct ModeToggleView: View {
    @Bindable var viewModel: TimetableViewModel
    var body: some View {
        Picker("モード", selection: $viewModel.mode) {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 140)
    }
}
