import SwiftUI

// MARK: - TimetableCellView

struct TimetableCellView: View {
    let courses: [Course]
    let day: Int
    let period: Int
    @Bindable var viewModel: TimetableViewModel

    @Environment(\.modelContext) private var modelContext

    /// DragGesture(minimumDistance:0) でプレス状態を追跡。
    /// contextMenu の長押しと共存できる（SwiftUI のジェスチャ優先度により
    /// contextMenu が長押しを先取りするため両立する）。
    @GestureState private var isPressed = false
    @State private var showCourseDetail: Course?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if courses.isEmpty {
                emptyCellView
            } else if courses.count == 1, let course = courses.first {
                singleCourseView(course)
            } else {
                multiCourseView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        // プレスフィードバック: scale 0.97 + spring
        .scaleEffect(isPressed ? 0.97 : 1.0, anchor: .center)
        .animation(
            isPressed
                ? .spring(response: 0.15, dampingFraction: 0.70)
                : .spring(response: 0.25, dampingFraction: 0.80),
            value: isPressed
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in
                    if !state { HapticFeedback.light() }
                    state = true
                }
        )
        .sheet(item: $showCourseDetail) { course in
            NavigationStack {
                CourseDetailView(course: course, viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty Cell

    private var emptyCellView: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .overlay(
                viewModel.isRegistrationMode
                    ? Image(systemName: "plus")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color(.systemGray3))
                        .transition(.opacity)
                    : nil
            )
    }

    // MARK: - Single Course

    private func singleCourseView(_ course: Course) -> some View {
        let bgColor = Color(hex: course.colorHex)
        let textColor: Color = bgColor.isLight ? .black : .white

        return ZStack(alignment: .topLeading) {
            bgColor

            VStack(alignment: .leading, spacing: 3) {
                // 授業名: 2行まで、semibold 11pt
                HStack(alignment: .top, spacing: 2) {
                    Text(course.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if course.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(textColor.opacity(0.8))
                    }
                }

                Spacer(minLength: 0)

                // ボトム: 単位バッジ + 教員ドット
                // 9pt の極小テキストを廃止し、コンパクトな視覚インジケーターに置換
                HStack(spacing: 4) {
                    Text("\(course.credits)単")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(textColor.opacity(0.75))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(textColor.opacity(0.15))
                        .clipShape(Capsule())

                    // 教員が設定されていることを示すドット（名前はセル内に収まらない）
                    if !course.instructor.isEmpty {
                        Circle()
                            .fill(textColor.opacity(0.5))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .padding(5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if viewModel.isRegistrationMode {
                if viewModel.selectedCourses.contains(course.id) {
                    viewModel.toggleCourseSelection(course.id)
                } else {
                    showCourseDetail = course
                }
            } else {
                showCourseDetail = course
            }
            HapticFeedback.light()
        }
        .contextMenu {
            courseContextMenu(course)
        }
    }

    // MARK: - Multi Course (Conflict Display)
    // オフセット重ね方式を廃止。
    // 主授業をセル背景に表示し、競合数バッジ + カラードット行で他授業を示す。

    private var multiCourseView: some View {
        let primary = courses[0]
        let alternatives = Array(courses.dropFirst())
        let bgColor = Color(hex: primary.colorHex)
        let textColor: Color = bgColor.isLight ? .black : .white

        return ZStack(alignment: .topLeading) {
            bgColor

            VStack(alignment: .leading, spacing: 3) {
                // 主授業名 + 競合数バッジ
                HStack(alignment: .top, spacing: 2) {
                    Text(primary.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    // 競合数を赤バッジで示す
                    Text("+\(alternatives.count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 0)

                // 競合授業のカラードット
                HStack(spacing: 3) {
                    ForEach(alternatives, id: \.id) { alt in
                        Circle()
                            .fill(Color(hex: alt.colorHex))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.6), lineWidth: 0.5)
                            )
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(5)
        }
        .contextMenu {
            // 各授業をサブメニューにグループ化
            ForEach(courses) { course in
                Menu(course.name) {
                    courseContextMenu(course)
                }
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func courseContextMenu(_ course: Course) -> some View {
        if viewModel.isRegistrationMode {
            Button {
                HapticFeedback.rigid()
                viewModel.toggleLock(course: course, context: modelContext)
            } label: {
                Label(
                    course.isLocked ? "ロック解除" : "ロック",
                    systemImage: course.isLocked ? "lock.open" : "lock"
                )
            }

            Button {
                viewModel.removeCourse(course, day: day, period: period, context: modelContext)
            } label: {
                Label("このコマから削除", systemImage: "xmark.circle")
            }
            .disabled(course.isLocked)

            Button {
                viewModel.toggleCourseSelection(course.id)
            } label: {
                Label(
                    viewModel.selectedCourses.contains(course.id) ? "選択解除" : "選択（一括色変更）",
                    systemImage: viewModel.selectedCourses.contains(course.id)
                        ? "checkmark.circle.fill" : "circle"
                )
            }

            Divider()
        }

        NavigationLink {
            CourseDetailView(course: course, viewModel: viewModel)
        } label: {
            Label("詳細・メモ", systemImage: "info.circle")
        }
    }
}
