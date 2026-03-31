import Foundation
import SwiftUI

// MARK: - Transit Models

struct TrainRoute: Identifiable {
    let id = UUID()
    let departure: String       // 出発駅
    let arrival: String         // 到着駅
    let departureTime: Date
    let arrivalTime: Date
    let duration: Int           // 所要時間（分）
    let transfers: Int          // 乗り換え回数
    let fare: Int               // 料金（円）
    let lines: [String]         // 利用路線
    let isRecommended: Bool
}

struct TrainDelayInfo: Identifiable {
    let id = UUID()
    let lineName: String
    let status: DelayStatus
    let message: String
    let updatedAt: Date
}

enum DelayStatus {
    case normal, delay, suspended, other

    var label: String {
        switch self {
        case .normal:    return "平常運転"
        case .delay:     return "遅延"
        case .suspended: return "運転見合わせ"
        case .other:     return "情報あり"
        }
    }

    var color: Color {
        switch self {
        case .normal:    return .green
        case .delay:     return .orange
        case .suspended: return .red
        case .other:     return .yellow
        }
    }
    var icon: String {
        switch self {
        case .normal:    return "checkmark.circle.fill"
        case .delay:     return "exclamationmark.triangle.fill"
        case .suspended: return "xmark.octagon.fill"
        case .other:     return "info.circle.fill"
        }
    }
}

// MARK: - ODPT API Response Models

private struct ODPTTrainInformation: Decodable {
    let railway: String
    let trainInformationText: ODPTMultiLangText?
    let trainInformationStatus: String?

    enum CodingKeys: String, CodingKey {
        case railway = "odpt:railway"
        case trainInformationText = "odpt:trainInformationText"
        case trainInformationStatus = "odpt:trainInformationStatus"
    }
}

private struct ODPTMultiLangText: Decodable {
    let ja: String?
    let en: String?

    enum CodingKeys: String, CodingKey {
        case ja = "ja"
        case en = "en"
    }
}

// MARK: - TransitViewModel

@MainActor
@Observable
final class TransitViewModel {

    // ODPT API (Open Data for Public Transportation)
    // APIキーは設定画面から設定できる
    var odptApiKey: String = UserDefaults.standard.string(forKey: "odpt_api_key") ?? ""
    var isLoading: Bool = false
    var delayInfoList: [TrainDelayInfo] = []
    var suggestedRoutes: [TrainRoute] = []
    var errorMessage: String?
    var lastUpdated: Date?

    // MARK: - API Key

    func saveApiKey(_ key: String) {
        odptApiKey = key
        UserDefaults.standard.set(key, forKey: "odpt_api_key")
    }

    // MARK: - Delay Information (ODPT API)

    func fetchDelayInfo(lines: [String]) async {
        guard !odptApiKey.isEmpty else {
            errorMessage = "ODPTのAPIキーを設定してください"
            return
        }
        isLoading = true
        errorMessage = nil

        var urlComponents = URLComponents(string: "https://api.odpt.org/api/4/odpt:TrainInformation")!
        urlComponents.queryItems = [
            URLQueryItem(name: "acl:consumerKey", value: odptApiKey)
        ]

        guard let url = urlComponents.url else {
            errorMessage = "URLの生成に失敗しました"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                errorMessage = "APIエラー: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                isLoading = false
                return
            }

            let infoList = try JSONDecoder().decode([ODPTTrainInformation].self, from: data)
            delayInfoList = infoList.map { info in
                let status: DelayStatus
                let msg = info.trainInformationText?.ja ?? ""
                if msg.contains("遅延") {
                    status = .delay
                } else if msg.contains("見合わせ") || msg.contains("運転停止") {
                    status = .suspended
                } else if msg.contains("平常") || msg.isEmpty {
                    status = .normal
                } else {
                    status = .other
                }
                // 路線名を見やすく整形 (odpt.Railway:JR-East.Yamanote → 山手線)
                let lineName = info.railway.components(separatedBy: ".").last ?? info.railway

                return TrainDelayInfo(
                    lineName: lineName,
                    status: status,
                    message: msg.isEmpty ? "平常運転" : msg,
                    updatedAt: Date()
                )
            }
            .filter { info in
                // 指定路線のみフィルタ（空なら全件）
                if lines.isEmpty { return true }
                return lines.contains(where: { info.lineName.contains($0) })
            }

            lastUpdated = Date()
        } catch {
            errorMessage = "データの取得に失敗: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Mock Route Suggestion (定期券ルートベース)
    // 実際のルート検索APIはYahoo!乗換案内等が必要なため、
    // 定期券情報とODPT遅延情報を組み合わせた推奨ルートを生成

    func suggestRoutes(from homeStation: String,
                       to arrivalStation: String,
                       departureTime: Date,
                       transitPassLine: String) async {
        guard !homeStation.isEmpty, !arrivalStation.isEmpty else {
            errorMessage = "出発駅・到着駅を設定してください"
            return
        }
        isLoading = true
        suggestedRoutes = []

        // 定期券路線に遅延があるかチェック
        let hasDelay = delayInfoList.contains {
            $0.status == .delay || $0.status == .suspended
        }

        // モックルート生成（実際のAPIレスポンスの代替）
        var routes: [TrainRoute] = []

        let baseTime = departureTime
        let arrivalTime1 = baseTime.addingTimeInterval(35 * 60)

        // メインルート（定期券路線）
        let mainRoute = TrainRoute(
            departure: homeStation,
            arrival: arrivalStation,
            departureTime: baseTime,
            arrivalTime: arrivalTime1,
            duration: 35,
            transfers: 1,
            fare: 0,  // 定期券利用のため無料
            lines: transitPassLine.isEmpty ? ["（定期券路線）"] : [transitPassLine],
            isRecommended: !hasDelay
        )
        routes.append(mainRoute)

        // 代替ルート（遅延時に推奨）
        if hasDelay {
            let altRoute = TrainRoute(
                departure: homeStation,
                arrival: arrivalStation,
                departureTime: baseTime.addingTimeInterval(-5 * 60),
                arrivalTime: baseTime.addingTimeInterval(42 * 60),
                duration: 42,
                transfers: 2,
                fare: 280,
                lines: ["（代替ルート）"],
                isRecommended: true
            )
            routes.append(altRoute)
        }

        suggestedRoutes = routes
        isLoading = false
    }
}
