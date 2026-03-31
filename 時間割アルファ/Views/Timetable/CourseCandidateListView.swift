import SwiftUI
import SwiftData

// MARK: - CourseCandidateListView

struct CourseCandidateListView: View {
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showAddCourse = false
    @State private var showOCR = false

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("授業候補")
                    .font(.headline)
                    .padding(.leading, 12)
                Spacer()
                Button {
                    showOCR = true
                } label: {
                    Label("OCR追加", systemImage: "doc.viewfinder")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button {
                    showAddCourse = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .padding(.trailing, 12)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("授業名・教員名で検索", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))

            // 候補リスト
            if viewModel.filteredCandidates.isEmpty {
                HStack {
                    Spacer()
                    Text(viewModel.searchText.isEmpty ? "候補がありません" : "見つかりません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(viewModel.filteredCandidates) { course in
                            CandidateCourseChip(course: course, viewModel: viewModel)
                                .onDrag {
                                    NSItemProvider(object: course.id.uuidString as NSString)
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
        .sheet(isPresented: $showAddCourse) {
            AddCourseView(viewModel: viewModel)
        }
        .sheet(isPresented: $showOCR) {
            OCRImagePickerView(viewModel: viewModel)
        }
    }
}

// MARK: - CandidateCourseChip

struct CandidateCourseChip: View {
    let course: Course
    @Bindable var viewModel: TimetableViewModel
    @Environment(\.modelContext) private var modelContext

    @State private var showDetail = false

    var body: some View {
        let isSelected = viewModel.selectedCourses.contains(course.id)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: course.colorHex))
                    .frame(width: 8, height: 8)
                Text(course.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            if !course.subtitle.isEmpty {
                Text(course.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("\(course.instructor) / \(course.credits)単位")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: course.colorHex).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color(hex: course.colorHex) : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            viewModel.toggleCourseSelection(course.id)
        }
        .contextMenu {
            Button {
                showDetail = true
            } label: {
                Label("詳細・メモ", systemImage: "info.circle")
            }

            Button(role: .destructive) {
                viewModel.deleteCourse(course, context: modelContext)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showDetail) {
            NavigationStack {
                CourseDetailView(course: course, viewModel: viewModel)
            }
        }
    }
}
