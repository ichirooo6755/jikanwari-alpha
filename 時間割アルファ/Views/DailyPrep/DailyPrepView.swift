import SwiftUI
import SwiftData

// MARK: - DailyPrepView (メインタブ)

struct DailyPrepView: View {
    @State private var alarmVM = AlarmViewModel()
    @State private var transitVM = TransitViewModel()
    @State private var selectedTab = 0
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DepartureSchedule.dayOfWeek)
    private var schedules: [DepartureSchedule]

    // 今日のスケジュール
    private var todaySchedule: DepartureSchedule? {
        let today = Calendar.current.component(.weekday, from: Date()) - 2  // 1=日曜→-1, 2=月曜→0
        return schedules.first { $0.dayOfWeek == today && $0.isEnabled }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // 今日の準備
                TodayOverviewView(
                    alarmVM: alarmVM,
                    transitVM: transitVM,
                    schedule: todaySchedule
                )
                .tabItem { Label("今日", systemImage: "sun.max.fill") }
                .tag(0)

                // 持ち物チェックリスト
                BelongingsChecklistView(
                    schedule: todaySchedule,
                    allSchedules: schedules
                )
                .tabItem { Label("持ち物", systemImage: "checklist") }
                .tag(1)

                // 電車情報
                TransitInfoView(
                    transitVM: transitVM,
                    schedule: todaySchedule
                )
                .tabItem { Label("電車", systemImage: "tram.fill") }
                .tag(2)

                // スケジュール設定
                ScheduleSettingsView(
                    alarmVM: alarmVM,
                    schedules: schedules
                )
                .tabItem { Label("設定", systemImage: "gear") }
                .tag(3)
            }
            .navigationTitle("お出かけ準備")
            .navigationBarTitleDisplayMode(.large)
        }
        // フルスクリーンアラーム
        .fullScreenCover(isPresented: $alarmVM.isAlarmFiring) {
            if let schedule = alarmVM.firingSchedule {
                AlarmFiringView(alarmVM: alarmVM, schedule: schedule)
            }
        }
        .task {
            await alarmVM.checkPermission()
            alarmVM.registerNotificationCategories()
            if let schedule = todaySchedule {
                await transitVM.fetchDelayInfo(lines: [schedule.transitPassLine])
            }
        }
        .onAppear {
            ensureDefaultSchedules()
        }
    }

    private func ensureDefaultSchedules() {
        // 月〜金のスケジュールがなければ作成
        for day in 0..<5 {
            if !schedules.contains(where: { $0.dayOfWeek == day }) {
                let schedule = DepartureSchedule(dayOfWeek: day)
                modelContext.insert(schedule)
                // デフォルト持ち物を追加
                let defaults: [(String, String)] = [
                    ("財布", "💴"), ("スマートフォン", "📱"), ("鍵", "🔑"),
                    ("交通系ICカード", "🎫"), ("筆記用具", "✏️")
                ]
                for (i, (name, emoji)) in defaults.enumerated() {
                    let item = BelongingsItem(name: name, emoji: emoji, isDefault: true, sortOrder: i)
                    modelContext.insert(item)
                    schedule.belongingsItems.append(item)
                }
            }
        }
        try? modelContext.save()
    }
}

// MARK: - TodayOverviewView

struct TodayOverviewView: View {
    let alarmVM: AlarmViewModel
    @Bindable var transitVM: TransitViewModel
    let schedule: DepartureSchedule?

    @State private var cardsVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let schedule {
                    // 出発時刻カード（stagger delay 0ms）
                    departureCard(schedule: schedule)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 16)
                        .animation(.spring(response: 0.4, dampingFraction: 0.80).delay(0.00), value: cardsVisible)

                    // 遅延情報サマリー（stagger delay 60ms）
                    delayStatusCard
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 16)
                        .animation(.spring(response: 0.4, dampingFraction: 0.80).delay(0.06), value: cardsVisible)

                    // ルート提案カード（stagger delay 120ms）
                    if !transitVM.suggestedRoutes.isEmpty {
                        routeCard
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 16)
                            .animation(.spring(response: 0.4, dampingFraction: 0.80).delay(0.12), value: cardsVisible)
                    }

                    // 持ち物チェック（stagger delay 180ms）
                    belongingsSummaryCard(schedule: schedule)
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 16)
                        .animation(.spring(response: 0.4, dampingFraction: 0.80).delay(0.18), value: cardsVisible)
                } else {
                    VStack(spacing: 12) {
                        Spacer(minLength: 60)
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("今日は授業がないか、\nスケジュールが設定されていません")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            cardsVisible = true
        }
        .refreshable {
            if let schedule {
                let line = schedule.transitPassLine
                let home = schedule.homeStationName
                let arrival = schedule.arrivalStationName
                let dep = schedule.departureTime
                await transitVM.fetchDelayInfo(lines: [line])
                await transitVM.suggestRoutes(from: home, to: arrival, departureTime: dep, transitPassLine: line)
            }
        }
    }

    private func departureCard(schedule: DepartureSchedule) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label("出発時刻", systemImage: "clock.fill")
                    .font(.headline)
                Spacer()
                Text(TimeSlot.dayNames[schedule.dayOfWeek] + "曜日")
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom) {
                Text(schedule.departureTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("アラーム", systemImage: "alarm.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(schedule.wakeUpAlarmTime.formatted(date: .omitted, time: .shortened))
                        .font(.title3).fontWeight(.semibold)
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            HStack {
                Label(schedule.homeStationName.isEmpty ? "出発駅未設定" : schedule.homeStationName,
                      systemImage: "arrow.up.circle")
                    .foregroundStyle(schedule.homeStationName.isEmpty ? .secondary : .primary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Label(schedule.arrivalStationName.isEmpty ? "到着駅未設定" : schedule.arrivalStationName,
                      systemImage: "mappin.circle.fill")
                    .foregroundStyle(schedule.arrivalStationName.isEmpty ? .secondary : .primary)
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // 2層シャドウ: 光の物理をシミュレートして奥行きを出す
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }

    private var delayStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("電車情報", systemImage: "tram.fill")
                    .font(.headline)
                Spacer()
                if transitVM.isLoading {
                    ProgressView().scaleEffect(0.8)
                } else if let updated = transitVM.lastUpdated {
                    Text(updated.formatted(date: .omitted, time: .shortened) + "更新")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if transitVM.delayInfoList.isEmpty {
                if transitVM.odptApiKey.isEmpty {
                    Label("設定タブでODPT APIキーを設定してください", systemImage: "key")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("情報なし（下に引っ張って更新）")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ForEach(transitVM.delayInfoList.prefix(3)) { info in
                    HStack {
                        Image(systemName: info.status.icon)
                            .foregroundStyle(info.status.color)
                        Text(info.lineName)
                            .font(.subheadline)
                        Spacer()
                        Text(info.status.label)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(info.status.color.opacity(0.15))
                            .foregroundStyle(info.status.color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // 2層シャドウ: 光の物理をシミュレートして奥行きを出す
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("おすすめルート", systemImage: "map.fill").font(.headline)
            ForEach(transitVM.suggestedRoutes) { route in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if route.isRecommended {
                            Text("おすすめ").font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15)).foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text("\(route.duration)分")
                            .font(.headline)
                        Text("乗換\(route.transfers)回")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(route.departureTime.formatted(date: .omitted, time: .shortened))
                        Image(systemName: "arrow.right").foregroundStyle(.secondary)
                        Text(route.arrivalTime.formatted(date: .omitted, time: .shortened))
                        Spacer()
                        Text(route.fare == 0 ? "定期券" : "¥\(route.fare)")
                            .font(.caption).foregroundStyle(route.fare == 0 ? .green : .primary)
                    }
                    .font(.subheadline)
                    Text(route.lines.joined(separator: " → "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if route.id != transitVM.suggestedRoutes.last?.id { Divider() }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // 2層シャドウ: 光の物理をシミュレートして奥行きを出す
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }

    private func belongingsSummaryCard(schedule: DepartureSchedule) -> some View {
        let total = schedule.belongingsItems.count
        let checked = schedule.belongingsItems.filter(\.isChecked).count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("持ち物", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                Text("\(checked)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(checked == total ? .green : .orange)
            }
            ProgressView(value: Double(checked), total: Double(max(total, 1)))
                .tint(checked == total ? .green : .orange)
            if checked < total {
                Text("あと\(total - checked)個未チェック")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("全て確認済み ✓")
                    .font(.caption).foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // 2層シャドウ: 光の物理をシミュレートして奥行きを出す
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}
