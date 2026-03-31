import SwiftUI

// MARK: - TransitInfoView

struct TransitInfoView: View {
    @Bindable var transitVM: TransitViewModel
    let schedule: DepartureSchedule?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 遅延情報
                delaySection

                // ルート提案
                if schedule != nil {
                    routeSection
                }
            }
            .padding()
        }
        .refreshable {
            if let s = schedule {
                let line = s.transitPassLine
                let home = s.homeStationName
                let arrival = s.arrivalStationName
                let depTime = s.departureTime
                await transitVM.fetchDelayInfo(lines: [line])
                await transitVM.suggestRoutes(from: home, to: arrival, departureTime: depTime, transitPassLine: line)
            }
        }
        .task {
            if let s = schedule, transitVM.delayInfoList.isEmpty {
                let line = s.transitPassLine
                await transitVM.fetchDelayInfo(lines: [line])
            }
        }
    }

    // MARK: - Delay Section

    private var delaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("遅延・運行情報", systemImage: "tram.fill")
                    .font(.headline)
                Spacer()
                if transitVM.isLoading {
                    ProgressView().scaleEffect(0.8)
                }
                if let updated = transitVM.lastUpdated {
                    Text(updated.formatted(date: .omitted, time: .shortened))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let err = transitVM.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if transitVM.odptApiKey.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("設定タブでODPT APIキーを入力すると\n遅延情報が表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if transitVM.delayInfoList.isEmpty && !transitVM.isLoading {
                Text("情報なし（下に引っ張って更新）")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(transitVM.delayInfoList) { info in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: info.status.icon)
                                .foregroundStyle(info.status.color)
                            Text(info.lineName)
                                .font(.subheadline).fontWeight(.semibold)
                            Spacer()
                            Text(info.status.label)
                                .font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(info.status.color.opacity(0.15))
                                .foregroundStyle(info.status.color)
                                .clipShape(Capsule())
                        }
                        if info.status != .normal {
                            Text(info.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                    .padding(.vertical, 4)
                    if info.id != transitVM.delayInfoList.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Route Section

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("ルート提案", systemImage: "map.fill")
                    .font(.headline)
                Spacer()
                if let s = schedule {
                    Button {
                        Task {
                            await transitVM.suggestRoutes(
                                from: s.homeStationName,
                                to: s.arrivalStationName,
                                departureTime: s.departureTime,
                                transitPassLine: s.transitPassLine
                            )
                        }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if transitVM.suggestedRoutes.isEmpty {
                Button {
                    guard let s = schedule else { return }
                    Task {
                        await transitVM.suggestRoutes(
                            from: s.homeStationName,
                            to: s.arrivalStationName,
                            departureTime: s.departureTime,
                            transitPassLine: s.transitPassLine
                        )
                    }
                } label: {
                    Label("ルートを検索", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                ForEach(transitVM.suggestedRoutes) { route in
                    routeRow(route)
                    if route.id != transitVM.suggestedRoutes.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func routeRow(_ route: TrainRoute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if route.isRecommended {
                    Text("おすすめ")
                        .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue).foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Spacer()
                Text("\(route.duration)分")
                    .font(.title3).fontWeight(.bold)
                Text("/ 乗換\(route.transfers)回")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(route.departureTime.formatted(date: .omitted, time: .shortened))
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Text(route.arrivalTime.formatted(date: .omitted, time: .shortened))
                    .fontWeight(.semibold)
                Spacer()
                Text(route.fare == 0 ? "🎫 定期券" : "¥\(route.fare)")
                    .font(.subheadline)
                    .foregroundStyle(route.fare == 0 ? .green : .primary)
            }
            Text(route.lines.joined(separator: " → "))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
