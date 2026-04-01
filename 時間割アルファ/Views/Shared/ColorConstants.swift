import SwiftUI

// MARK: - Haptic Feedback Utility
// 全画面から使う共通ハプティクスユーティリティ。
// prepare() を impactOccurred() の直前に呼ぶことで Taptic Engine を
// プリロードし、視覚フィードバックと同期して発火させる。

enum HapticFeedback {
    /// 軽いタップ: セルタップ・リスト行選択
    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        g.impactOccurred()
    }

    /// 中程度: FAB プレス・モード切替・色選択
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.prepare()
        g.impactOccurred()
    }

    /// 硬い: 確定・ロック/ロック解除など意思決定アクション
    static func rigid() {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare()
        g.impactOccurred()
    }

    /// 成功通知: 授業追加完了・確定完了
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.success)
    }

    /// 警告通知: 競合検出
    static func warning() {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(.warning)
    }
}

// MARK: - Pressable Button Styles
// Emil Kowalski の「ボタンはレスポンシブに感じさせよ」を実装。
// 押込み時に scale 0.97 + spring、離し時に自然な戻りを提供する。

struct PressableButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0, anchor: .center)
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.15, dampingFraction: 0.70)
                    : .spring(response: 0.25, dampingFraction: 0.80),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { HapticFeedback.light() }
            }
    }
}

/// FAB 専用: より強いスケール(0.92)と高速レスポンス
struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0, anchor: .center)
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.12, dampingFraction: 0.60)
                    : .spring(response: 0.30, dampingFraction: 0.75),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { HapticFeedback.medium() }
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { .init() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { .init(scaleAmount: scale) }
}

// MARK: - Course Color Presets

struct CourseColors {
    static let presets: [String] = [
        "#4A90D9", // ブルー
        "#7B68EE", // パープル
        "#50C878", // グリーン
        "#FF6B6B", // レッド
        "#E8850A", // オレンジ（白文字対応・アクセシブル）
        "#87CEEB", // スカイブルー
        "#DDA0DD", // プラム
        "#98FB98", // ペールグリーン
        "#F0E68C", // カーキ
        "#FFB6C1", // ライトピンク
        "#20B2AA", // ティール
        "#FF8C00", // ダークオレンジ
    ]
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    var isLight: Bool {
        let uiColor = UIColor(self)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.45
    }
}
