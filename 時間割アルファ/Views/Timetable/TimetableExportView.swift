import SwiftUI

// MARK: - TimetableExportView
// 時間割を画像としてエクスポートするためのView

struct TimetableShareButton: View {
    let semester: Semester
    let viewModel: TimetableViewModel

    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false

    var body: some View {
        Button {
            renderAndShare()
        } label: {
            Label("画像で共有", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ShareSheet(items: [image])
            }
        }
    }

    @MainActor
    private func renderAndShare() {
        let renderer = ImageRenderer(
            content: TimetableSnapshotView(semester: semester, viewModel: viewModel)
                .frame(width: 800, height: 600)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 2.0
        renderedImage = renderer.uiImage
        showShareSheet = renderedImage != nil
    }
}

// MARK: - TimetableSnapshotView (エクスポート用、シンプル版)

struct TimetableSnapshotView: View {
    let semester: Semester
    let viewModel: TimetableViewModel

    private let periods = 1...5
    private let days = 0...5

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            Text(semester.name)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            HStack(spacing: 1) {
                // 時限列
                Text("")
                    .frame(width: 30)

                ForEach(days, id: \.self) { day in
                    Text(TimeSlot.dayNames[day])
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 28)
                        .background(Color(.systemGray5))
                }
            }

            ForEach(periods, id: \.self) { period in
                HStack(spacing: 1) {
                    Text("\(period)")
                        .font(.caption2)
                        .frame(width: 30)
                        .frame(minHeight: 70)
                        .background(Color(.systemGray5))

                    ForEach(days, id: \.self) { day in
                        let courses = viewModel.courses(day: day, period: period)
                        snapshotCell(courses)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 70)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
    }

    @ViewBuilder
    private func snapshotCell(_ courses: [Course]) -> some View {
        if courses.isEmpty {
            Rectangle()
                .fill(Color(.systemGray6))
                .overlay(
                    Rectangle()
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
        } else if let course = courses.first {
            let bgColor = Color(hex: course.colorHex)
            ZStack(alignment: .topLeading) {
                bgColor
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(bgColor.isLight ? .black : .white)
                        .lineLimit(2)
                    if !course.instructor.isEmpty {
                        Text(course.instructor)
                            .font(.system(size: 9))
                            .foregroundStyle((bgColor.isLight ? Color.black : .white).opacity(0.7))
                    }
                }
                .padding(4)
            }
            .overlay(
                Rectangle()
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
