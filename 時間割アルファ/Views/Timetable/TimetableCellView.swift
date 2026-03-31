import SwiftUI

// MARK: - TimetableCellView

struct TimetableCellView: View {
    let courses: [Course]
    let day: Int
    let period: Int
    @Bindable var viewModel: TimetableViewModel

    @Environment(\.modelContext) private var modelContext

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
        .frame(minHeight: 70)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }

    // MARK: - Empty Cell

    private var emptyCellView: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .overlay(
                viewModel.isRegistrationMode ?
                Image(systemName: "plus")
                    .foregroundStyle(Color(.systemGray3))
                    .font(.caption)
                : nil
            )
    }

    // MARK: - Single Course

    private func singleCourseView(_ course: Course) -> some View {
        let bgColor = Color(hex: course.colorHex)
        let textColor: Color = bgColor.isLight ? .black : .white

        return ZStack(alignment: .topLeading) {
            bgColor
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 2) {
                    Text(course.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if course.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(textColor.opacity(0.8))
                    }
                }
                if !course.subtitle.isEmpty {
                    Text(course.subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(textColor.opacity(0.8))
                        .lineLimit(1)
                }
                if !course.instructor.isEmpty {
                    Text(course.instructor)
                        .font(.system(size: 9))
                        .foregroundStyle(textColor.opacity(0.7))
                        .lineLimit(1)
                }
                Text("\(course.credits)単位")
                    .font(.system(size: 9))
                    .foregroundStyle(textColor.opacity(0.7))
            }
            .padding(5)
        }
        .contextMenu {
            courseContextMenu(course)
        }
        .onTapGesture {
            if viewModel.selectedCourses.contains(course.id) {
                viewModel.toggleCourseSelection(course.id)
            }
        }
    }

    // MARK: - Multi Course (Overlapped)

    private var multiCourseView: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                let bgColor = Color(hex: course.colorHex)
                let textColor: Color = bgColor.isLight ? .black : .white
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text("\(index + 1). \(course.name)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if course.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(textColor.opacity(0.8))
                        }
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bgColor)
                .offset(y: CGFloat(index) * 22)
                .contextMenu {
                    courseContextMenu(course)
                }
            }
        }
        .frame(minHeight: CGFloat(courses.count) * 22 + 10)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func courseContextMenu(_ course: Course) -> some View {
        if viewModel.isRegistrationMode {
            Button {
                viewModel.toggleLock(course: course, context: modelContext)
            } label: {
                Label(course.isLocked ? "ロック解除" : "ロック", systemImage: course.isLocked ? "lock.open" : "lock")
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
                Label(viewModel.selectedCourses.contains(course.id) ? "選択解除" : "選択（一括色変更）",
                      systemImage: viewModel.selectedCourses.contains(course.id) ? "checkmark.circle.fill" : "circle")
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
