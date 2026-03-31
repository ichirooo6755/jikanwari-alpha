import SwiftUI
import SwiftData

// MARK: - ContentView (Root)

struct ContentView: View {
    @State private var viewModel = TimetableViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 時間割タブ
            NavigationStack {
                TimetableView(viewModel: viewModel)
                    .navigationTitle("時間割アルファ")
                    .toolbar {
                        if let semester = viewModel.selectedSemester {
                            ToolbarItem(placement: .primaryAction) {
                                TimetableShareButton(semester: semester, viewModel: viewModel)
                            }
                        }
                    }
            }
            .tabItem {
                Label("時間割", systemImage: "calendar")
            }
            .tag(0)

            // お出かけ準備タブ
            DailyPrepView()
                .tabItem {
                    Label("お出かけ", systemImage: "figure.walk")
                }
                .tag(1)

            // メモタブ
            NotesListView()
                .tabItem {
                    Label("メモ", systemImage: "note.text")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Course.self,
            TimeSlot.self,
            CourseNote.self,
            NoteAttachment.self,
            GeneralNote.self,
            GeneralNoteAttachment.self,
            Semester.self,
            DepartureSchedule.self,
            BelongingsItem.self
        ], inMemory: true)
}
