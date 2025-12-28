import SwiftUI
import StoreKit

struct StealSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let service: MessageService
    let message: Message
    
    @Binding var rootKeyword: String
    
    @State private var newPasscode = ""
    @State private var isLoading = false
    @State private var showingAutoSetAlert = false
    @State private var showConfetti = true
    
    // ★追加: 4桁アップグレード関連
    @State private var is4DigitMode: Bool
    @State private var showingUpgradeAlert = false
    @State private var isUpgrading = false
    @State private var upgradeError: String?
    
    // Instagram Colors
    private let instagramGradient = LinearGradient(
        colors: [
            Color(red: 131/255, green: 58/255, blue: 180/255),
            Color(red: 253/255, green: 29/255, blue: 29/255),
            Color(red: 252/255, green: 176/255, blue: 69/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let goldGradient = LinearGradient(
        colors: [
            Color(red: 255/255, green: 215/255, blue: 0/255),
            Color(red: 255/255, green: 193/255, blue: 37/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let subtleGray = Color(red: 250/255, green: 250/255, blue: 250/255)
    
    init(service: MessageService, message: Message, rootKeyword: Binding<String>) {
        self.service = service
        self.message = message
        self._rootKeyword = rootKeyword
        // ★4桁モードを引き継ぐ
        self._is4DigitMode = State(initialValue: message.is_4_digit)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            if showConfetti {
                confettiOverlay
            }
            
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 40)
                    
                    // MARK: - Success Icon
                    successIcon
                    
                    // MARK: - Title
                    titleSection
                    
                    // MARK: - 4桁アップグレードセクション（3桁モードの場合のみ）
                    if !is4DigitMode {
                        upgradeSection
                    }
                    
                    // MARK: - Passcode Input
                    passcodeSection
                    
                    // MARK: - Submit Button
                    submitButton
                    
                    // MARK: - Skip Button
                    skipButton
                    
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 32)
            }
        }
        .alert("設定未完了", isPresented: $showingAutoSetAlert) {
            Button("確認") {
                rootKeyword = ""
                dismiss()
            }
        } message: {
            Text("暗証番号は「\(is4DigitMode ? "0000" : "000")」に設定され、投稿は「非公開」になりました。\n\n24時間以内に設定しない場合、暗証番号「\(is4DigitMode ? "0000" : "000")」のまま自動的に公開されます。")
        }
        .alert("4桁モードにアップグレード", isPresented: $showingUpgradeAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("購入する (¥500)") {
                Task { await purchaseUpgrade() }
            }
        } message: {
            Text("4桁モードにすると、暗証番号が0000〜9999の10,000通りになり、奪われにくくなります。\n\nこの投稿を4桁モードにアップグレードしますか？")
        }
        .interactiveDismissDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showConfetti = false
                }
            }
        }
    }
    
    // MARK: - Confetti Overlay
    private var confettiOverlay: some View {
        GeometryReader { proxy in
            ForEach(0..<30, id: \.self) { i in
                Circle()
                    .fill([Color.purple, Color.pink, Color.orange, Color.yellow][i % 4])
                    .frame(width: CGFloat.random(in: 8...16), height: CGFloat.random(in: 8...16))
                    .position(
                        x: CGFloat.random(in: 0...proxy.size.width),
                        y: CGFloat.random(in: 0...proxy.size.height)
                    )
                    .opacity(0.7)
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Success Icon
    private var successIcon: some View {
        ZStack {
            Circle()
                .stroke(instagramGradient, lineWidth: 4)
                .frame(width: 120, height: 120)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 100, height: 100)
            
            Image(systemName: "checkmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.green)
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("奪取成功！")
                .font(.title)
                .fontWeight(.bold)
            
            Text("この投稿はあなたのものになりました")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(message.keyword)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(instagramGradient)
                .cornerRadius(20)
        }
    }
    
    // MARK: - Upgrade Section (3桁の場合のみ表示)
    private var upgradeSection: some View {
        VStack(spacing: 12) {
            // 見出し
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("今だけ特別オファー！")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
            }
            
            // アップグレードカード
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🔒 4桁モードにアップグレード")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("10倍守りやすくなる！")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("¥500")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        Text("買い切り")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 比較
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("3桁")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("1,000通り")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 4) {
                        Text("4桁")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("10,000通り")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                // 購入ボタン
                Button {
                    showingUpgradeAlert = true
                } label: {
                    HStack {
                        if isUpgrading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "lock.shield.fill")
                            Text("4桁にアップグレード")
                        }
                    }
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(goldGradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isUpgrading)
                
                if let error = upgradeError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Passcode Section
    private var passcodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("新しい暗証番号")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Mode indicator
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                    Text(is4DigitMode ? "4桁モード" : "3桁モード")
                }
                .font(.caption)
                .foregroundColor(is4DigitMode ? .green : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((is4DigitMode ? Color.green : Color.orange).opacity(0.1))
                )
            }
            
            // Input
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.gray)
                
                TextField(is4DigitMode ? "新しい4桁番号" : "新しい3桁番号", text: $newPasscode)
                    .keyboardType(.numberPad)
                    .font(.title3)
            }
            .padding(16)
            .background(subtleGray)
            .cornerRadius(16)
            .onChange(of: newPasscode) { _, val in
                let limit = is4DigitMode ? 4 : 3
                if val.count > limit {
                    newPasscode = String(val.prefix(limit))
                }
            }
            
            Text("他の人に推測されにくい番号を設定しましょう")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(20)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            Task { await updatePasscode() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("設定して公開する")
                }
            }
            ..fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                newPasscode.isEmpty
                ? AnyShapeStyle(Color.gray.opacity(0.3))
                : AnyShapeStyle(instagramGradient)
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            }
        .disabled(newPasscode.isEmpty || isLoading)
    }
    
    // MARK: - Skip Button
    private var skipButton: some View {
        Button {
            showingAutoSetAlert = true
        } label: {
            Text("後で設定する")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Methods
    private func updatePasscode() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await service.updateMessage(
                message: message,
                keyword: message.keyword,
                body: message.body,
                shouldDeleteVoice: false,
                newVoiceData: nil,
                remainingImageUrls: message.image_urls ?? [],
                newImagesData: [],
                passcode: newPasscode,
                is4Digit: is4DigitMode
            )
            
            rootKeyword = ""
            dismiss()
            
        } catch {
            print("Update error: \(error)")
        }
    }
    
    private func purchaseUpgrade() async {
        isUpgrading = true
        upgradeError = nil
        defer { isUpgrading = false }
        
        // TODO: 実際のStoreKit課金処理を実装
        // 今は仮でアップグレード成功とする
        
        do {
            // 仮の処理時間
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // DBを4桁モードに更新
            _ = try await service.upgradeTo4Digit(message: message)
            
            await MainActor.run {
                withAnimation {
                    is4DigitMode = true
                    newPasscode = "" // 桁数が変わるのでリセット
                }
            }
        } catch {
            await MainActor.run {
                upgradeError = "アップグレードに失敗しました"
            }
        }
    }
}


// MARK: - StoreKit Helper (将来の課金実装用)
/*
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published var products: [Product] = []
    
    private let productIds = ["com.aikotoba.upgrade4digit"]
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                return true
            case .unverified:
                return false
            }
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }
}
*/
