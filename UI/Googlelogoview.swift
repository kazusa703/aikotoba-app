import SwiftUI

/// Googleロゴを表示するビュー
/// Assets.xcassetsに画像がない場合でも動作するカスタムロゴ
struct GoogleLogoView: View {
    var size: CGFloat = 18
    
    var body: some View {
        ZStack {
            // 背景の白い円
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
            
            // Gの文字（Googleカラー）
            Text("G")
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 66/255, green: 133/255, blue: 244/255),  // Blue
                            Color(red: 234/255, green: 67/255, blue: 53/255),   // Red
                            Color(red: 251/255, green: 188/255, blue: 5/255),   // Yellow
                            Color(red: 52/255, green: 168/255, blue: 83/255)    // Green
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        GoogleLogoView(size: 18)
        GoogleLogoView(size: 24)
        GoogleLogoView(size: 32)
        
        // ボタン内での使用例
        Button {
        } label: {
            HStack(spacing: 8) {
                GoogleLogoView()
                Text("Googleでサインイン")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .foregroundColor(.primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 32)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
