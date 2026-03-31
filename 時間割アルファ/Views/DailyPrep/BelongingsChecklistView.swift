import SwiftUI
import SwiftData

// MARK: - BelongingsChecklistView

struct BelongingsChecklistView: View {
    let schedule: DepartureSchedule?
    let allSchedules: [DepartureSchedule]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDay: Int = {
        let w = Calendar.current.component(.weekday, from: Date()) - 2
        return max(0, min(w, 5))
    }()
    @State private var showAddItem = false
    @State private var newItemName = ""
    @State private var newItemEmoji = "📦"
    @State private var newItemIsDefault = false

    private var currentSchedule: DepartureSchedule? {
        allSchedules.first { $0.dayOfWeek == selectedDay }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 曜日セレクター
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<6) { day in
                        Button {
                            selectedDay = day
                        } label: {
                            Text(TimeSlot.dayNames[day] + "曜")
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedDay == day ? Color.blue : Color(.systemGray5))
                                .foregroundStyle(selectedDay == day ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()

            if let sched = currentSchedule {
                let sorted = sched.belongingsItems.sorted { $0.sortOrder < $1.sortOrder }
                let defaults = sorted.filter { $0.isDefault }
                let extras = sorted.filter { !$0.isDefault }

                List {
                    // 必需品セクション
                    if !defaults.isEmpty {
                        Section {
                            ForEach(defaults) { item in
                                BelongingsItemRow(item: item, onToggle: {
                                    item.isChecked.toggle()
                                    try? modelContext.save()
                                })
                            }
                            .onDelete { offsets in
                                deleteItems(from: defaults, offsets: offsets, in: sched)
                            }
                        } header: {
                            Text("必需品")
                        }
                    }

                    // 追加アイテムセクション
                    Section {
                        ForEach(extras) { item in
                            BelongingsItemRow(item: item, onToggle: {
                                item.isChecked.toggle()
                                try? modelContext.save()
                            })
                        }
                        .onDelete { offsets in
                            deleteItems(from: extras, offsets: offsets, in: sched)
                        }

                        Button {
                            showAddItem = true
                        } label: {
                            Label("アイテムを追加", systemImage: "plus.circle")
                        }
                    } header: {
                        Text("その他")
                    }
                }
                .listStyle(.insetGrouped)

                // 一括リセット
                Button {
                    for item in sched.belongingsItems {
                        item.isChecked = false
                    }
                    try? modelContext.save()
                } label: {
                    Label("チェックをリセット", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding()
            } else {
                ContentUnavailableView(
                    "スケジュール未設定",
                    systemImage: "calendar.badge.plus",
                    description: Text("設定タブから\(TimeSlot.dayNames[selectedDay])曜のスケジュールを作成してください")
                )
            }
        }
        .alert("アイテムを追加", isPresented: $showAddItem) {
            TextField("持ち物の名前", text: $newItemName)
            TextField("絵文字", text: $newItemEmoji)
            Toggle("必需品として登録", isOn: $newItemIsDefault)
            Button("追加") {
                guard !newItemName.isEmpty, let sched = currentSchedule else { return }
                let item = BelongingsItem(
                    name: newItemName,
                    emoji: newItemEmoji.isEmpty ? "📦" : newItemEmoji,
                    isDefault: newItemIsDefault,
                    sortOrder: sched.belongingsItems.count
                )
                modelContext.insert(item)
                sched.belongingsItems.append(item)
                try? modelContext.save()
                newItemName = ""
                newItemEmoji = "📦"
                newItemIsDefault = false
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func deleteItems(from items: [BelongingsItem], offsets: IndexSet, in sched: DepartureSchedule) {
        for index in offsets {
            let item = items[index]
            sched.belongingsItems.removeAll { $0.id == item.id }
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

// MARK: - BelongingsItemRow

struct BelongingsItemRow: View {
    @Bindable var item: BelongingsItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.title3)

            Text(item.name)
                .strikethrough(item.isChecked, color: .secondary)
                .foregroundStyle(item.isChecked ? .secondary : .primary)

            Spacer()

            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isChecked ? .green : .secondary)
                .font(.title3)
                .onTapGesture { onToggle() }
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
