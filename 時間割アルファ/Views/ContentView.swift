import SwiftUI
import SwiftData

// MARK: - ContentView (Root)

struct ContentView: View {
    @State private var viewModel = TimetableViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 時間割タブ（ナビゲーションなし：グリッドを最大化）
            TimetableView(viewModel: viewModel)
                .tabItem {
                    Label("時間割", systemImage: selectedTab == 0 ? "calendar.fill" : "calendar")
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
                    Label("メモ", systemImage: selectedTab == 2 ? "note.text" : "note.text")
                }
                .tag(2)
        }
        .tint(.blue)
        // タブ切替時に軽い haptic フィードバック
        .onChange(of: selectedTab) { _, _ in
            HapticFeedback.light()
        }
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
