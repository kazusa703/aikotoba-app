import SwiftUI

// MARK: - App Color Palette (Based on Lock Icon)

struct AppColors {
    // Primary Colors
    static let primary = Color(hex: "5A7A8A")           // スレートブルー（背景色）
    static let primaryDark = Color(hex: "3D5A6C")       // ダークブルー
    static let primaryLight = Color(hex: "7A9BAB")      // ライトブルーグレー
    
    // Accent Colors
    static let accent = Color(hex: "4A90A4")            // アクセントブルー
    static let accentLight = Color(hex: "8BB8C8")       // ライトアクセント
    
    // Neutral Colors
    static let background = Color(hex: "F5F7F9")        // 背景グレー
    static let cardBackground = Color.white
    static let textPrimary = Color(hex: "2D3E4A")       // ダークグレー（テキスト）
    static let textSecondary = Color(hex: "6B7C88")     // セカンダリテキスト
    static let border = Color(hex: "D0D8DD")            // ボーダー
    
    // Semantic Colors
    static let success = Color(hex: "4CAF50")
    static let warning = Color(hex: "FF9800")
    static let error = Color(hex: "E53935")
    
    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [primaryDark, primary, primaryLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let subtleGradient = LinearGradient(
        colors: [primary.opacity(0.8), primaryLight.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let disabledGradient = LinearGradient(
        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
}
