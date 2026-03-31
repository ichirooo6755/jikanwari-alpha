import SwiftUI
import SwiftData

// MARK: - ScheduleSettingsView
// 曜日ごとの出発時刻・路線・通知設定

struct ScheduleSettingsView: View {
    @Bindable var alarmVM: AlarmViewModel
    let schedules: [DepartureSchedule]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedDay = 0
    @State private var showPermissionAlert = false

    private var currentSchedule: DepartureSchedule? {
        schedules.first { $0.dayOfWeek == selectedDay }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 通知許可バナー
                if !alarmVM.permissionGranted {
                    permissionBanner
                }

                // ODPT APIキー設定
                apiKeySection

                // 曜日セレクター
                daySelector

                // スケジュール設定
                if let sched = currentSchedule {
                    scheduleEditor(sched)
                }

                // テストアラームボタン
                if let sched = currentSchedule {
                    Button {
                        alarmVM.startAlarm(for: sched)
                    } label: {
                        Label("アラームをテスト", systemImage: "alarm.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("通知が許可されていません", systemImage: "bell.slash.fill")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.orange)
            Text("リマインダーとアラームを受け取るには通知を許可してください")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                Task { await alarmVM.requestPermission() }
            } label: {
                Text("通知を許可する")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("ODPT APIキー", systemImage: "key.fill")
                    .font(.headline)
                Spacer()
                Link("取得方法", destination: URL(string: "https://developer.odpt.org/")!)
                    .font(.caption)
            }
            SecureField("APIキーを入力", text: Binding(
                get: { alarmVM.isAlarmFiring ? "" : UserDefaults.standard.string(forKey: "odpt_api_key") ?? "" },
                set: { key in
                    UserDefaults.standard.set(key, forKey: "odpt_api_key")
                }
            ))
            .textFieldStyle(.roundedBorder)
            Text("ODPT（公共交通オープンデータ）の電車遅延情報に使用します")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Day Selector

    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("曜日を選択").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<6) { day in
                        let hasSched = schedules.contains { $0.dayOfWeek == day }
                        Button { selectedDay = day } label: {
                            VStack(spacing: 2) {
                                Text(TimeSlot.dayNames[day] + "曜")
                                    .font(.subheadline)
                                if hasSched {
                                    Circle().fill(Color.green).frame(width: 5, height: 5)
                                } else {
                                    Circle().fill(Color.clear).frame(width: 5, height: 5)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(selectedDay == day ? Color.blue : Color(.systemGray5))
                            .foregroundStyle(selectedDay == day ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Schedule Editor

    private func scheduleEditor(_ sched: DepartureSchedule) -> some View {
        VStack(spacing: 0) {
            // 有効化トグル
            HStack {
                Label("有効", systemImage: "power")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { sched.isEnabled },
                    set: { sched.isEnabled = $0; try? modelContext.save() }
                ))
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer().frame(height: 12)

            VStack(spacing: 0) {
                // 出発時刻
                DatePicker("出発時刻", selection: Binding(
                    get: { sched.departureTime },
                    set: { sched.departureTime = $0; sched.updatedAt = Date(); try? modelContext.save() }
                ), displayedComponents: .hourAndMinute)
                .padding()

                Divider().padding(.leading, 16)

                // 自宅最寄り駅
                HStack {
                    Text("自宅最寄り駅")
                    Spacer()
                    TextField("例: 渋谷", text: Binding(
                        get: { sched.homeStationName },
                        set: { sched.homeStationName = $0; try? modelContext.save() }
                    ))
                    .multilineTextAlignment(.trailing)
                }
                .padding()

                Divider().padding(.leading, 16)

                // 目的地最寄り駅
                HStack {
                    Text("目的地最寄り駅")
                    Spacer()
                    TextField("例: 東京", text: Binding(
                        get: { sched.arrivalStationName },
                        set: { sched.arrivalStationName = $0; try? modelContext.save() }
                    ))
                    .multilineTextAlignment(.trailing)
                }
                .padding()

                Divider().padding(.leading, 16)

                // 定期券路線
                HStack {
                    Text("定期券路線")
                    Spacer()
                    TextField("例: 山手線", text: Binding(
                        get: { sched.transitPassLine },
                        set: { sched.transitPassLine = $0; try? modelContext.save() }
                    ))
                    .multilineTextAlignment(.trailing)
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer().frame(height: 12)

            // アラーム時刻プレビュー
            VStack(alignment: .leading, spacing: 8) {
                Label("スケジュールプレビュー", systemImage: "clock")
                    .font(.headline)

                HStack {
                    Image(systemName: "moon.fill").foregroundStyle(.purple)
                    Text("前日夜9時リマインド")
                    Spacer()
                    Text("21:00")
                        .fontWeight(.semibold)
                }
                HStack {
                    Image(systemName: "alarm.fill").foregroundStyle(.orange)
                    Text("アラーム（出発40分前）")
                    Spacer()
                    Text(sched.wakeUpAlarmTime.formatted(date: .omitted, time: .shortened))
                        .fontWeight(.semibold).foregroundStyle(.orange)
                }
                HStack {
                    Image(systemName: "figure.walk").foregroundStyle(.blue)
                    Text("出発")
                    Spacer()
                    Text(sched.departureTime.formatted(date: .omitted, time: .shortened))
                        .fontWeight(.semibold).foregroundStyle(.blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer().frame(height: 12)

            // 通知再登録ボタン
            Button {
                Task {
                    await alarmVM.rescheduleAllNotifications(schedules: schedules)
                }
            } label: {
                Label("通知をすべて再登録", systemImage: "bell.badge.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}
