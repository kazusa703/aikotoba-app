import SwiftUI

struct StealSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    
    let service: MessageService
    let message: Message
    
    @Binding var rootKeyword: String
    
    @State private var newPasscode = ""
    @State private var isLoading = false
    @State private var showingAutoSetAlert = false
    @State private var showConfetti = true
    
    // 桁数選択
    @State private var selectedLength: Int
    @State private var showingUpgradeSheet = false
    @State private var upgradeTargetLength: Int = 4
    @State private var upgradePasscode = ""
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
    
    private let subtleGray = Color(red: 250/255, green: 250/255, blue: 250/255)
    
    init(service: MessageService, message: Message, rootKeyword: Binding<String>) {
        self.service = service
        self.message = message
        self._rootKeyword = rootKeyword
        self._selectedLength = State(initialValue: message.passcode_length)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            if showConfetti {
                confettiOverlay
            }
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)
                    
                    successIcon
                    titleSection
                    currentSecurityInfo
                    passcodeSection
                    upgradeOptions
                    submitButton
                    skipButton
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .alert("設定未完了", isPresented: $showingAutoSetAlert) {
            Button("確認") {
                rootKeyword = ""
                dismiss()
            }
        } message: {
            Text("暗証番号は「\(String(repeating: "0", count: selectedLength))」に設定され、投稿は「非公開」になりました。\n\n24時間後に自動的に公開されますが、暗証番号が簡単なため奪われやすい状態です。")
        }
        .sheet(isPresented: $showingUpgradeSheet) {
            upgradeSheetView
        }
        .interactiveDismissDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showConfetti = false }
            }
        }
    }
    
    // MARK: - Confetti
    private var confettiOverlay: some View {
        GeometryReader { proxy in
            ForEach(0..<30, id: \.self) { i in
                Circle()
                    .fill([Color.purple, Color.pink, Color.orange, Color.yellow][i % 4])
                    .frame(width: CGFloat.random(in: 8...16))
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
                .fill(Color.green.opacity(0.15))
                .frame(width: 100, height: 100)
            
            Image(systemName: "checkmark")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.green)
        }
    }
    
    // MARK: - Title
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
    
    // MARK: - Current Security Info
    private var currentSecurityInfo: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .font(.title2)
                .foregroundColor(securityColor(for: selectedLength))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("現在のセキュリティ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(selectedLength)桁 / \(combinationText(for: selectedLength))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            if selectedLength < 10 {
                Button {
                    upgradeTargetLength = selectedLength + 1
                    showingUpgradeSheet = true
                } label: {
                    Text("強化する")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(instagramGradient)
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(subtleGray)
        .cornerRadius(16)
    }
    
    // MARK: - Passcode Section
    private var passcodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("新しい暗証番号")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                    Text("\(selectedLength)桁")
                }
                .font(.caption)
                .foregroundColor(securityColor(for: selectedLength))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(securityColor(for: selectedLength).opacity(0.1))
                )
            }
            
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.gray)
                
                TextField(String(repeating: "0", count: selectedLength), text: $newPasscode)
                    .keyboardType(.numberPad)
                    .font(.title3)
            }
            .padding(16)
            .background(subtleGray)
            .cornerRadius(16)
            .onChange(of: newPasscode) { _, val in
                if val.count > selectedLength {
                    newPasscode = String(val.prefix(selectedLength))
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
    
    // MARK: - Upgrade Options
    private var upgradeOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🔒 セキュリティを強化")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableUpgrades, id: \.length) { product in
                        upgradeCard(product: product)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var availableUpgrades: [PasscodeLengthProduct] {
        PasscodeLengthProduct.availableUpgrades(from: selectedLength)
    }
    
    private func upgradeCard(product: PasscodeLengthProduct) -> some View {
        Button {
            upgradeTargetLength = product.length
            upgradePasscode = ""
            showingUpgradeSheet = true
        } label: {
            VStack(spacing: 8) {
                Text("\(product.length)桁")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(product.combinationCount)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(storeKit.displayPrice(for: product.length))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            .frame(width: 80, height: 90)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            Task { await updatePasscode() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("設定して公開する")
                }
            }
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                newPasscode.count == selectedLength
                ? instagramGradient
                : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(newPasscode.count != selectedLength || isLoading)
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
    
    // MARK: - Upgrade Sheet
    private var upgradeSheetView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(gradientForLength(upgradeTargetLength))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("\(upgradeTargetLength)桁にアップグレード")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("\(combinationText(for: upgradeTargetLength))の組み合わせで守られます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Price
                    Text(storeKit.displayPrice(for: upgradeTargetLength))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    // Comparison
                    comparisonView
                    
                    // Passcode Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新しい\(upgradeTargetLength)桁の暗証番号")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.gray)
                            
                            TextField(String(repeating: "0", count: upgradeTargetLength), text: $upgradePasscode)
                                .keyboardType(.numberPad)
                                .font(.title3)
                        }
                        .padding(16)
                        .background(subtleGray)
                        .cornerRadius(16)
                        .onChange(of: upgradePasscode) { _, val in
                            if val.count > upgradeTargetLength {
                                upgradePasscode = String(val.prefix(upgradeTargetLength))
                            }
                        }
                    }
                    
                    if let error = upgradeError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Purchase Button
                    Button {
                        Task { await purchaseUpgrade() }
                    } label: {
                        HStack {
                            if isUpgrading {
                                ProgressView().tint(.white)
                            } else {
                                Text("\(storeKit.displayPrice(for: upgradeTargetLength))で購入")
                                    .fontWeight(.bold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            upgradePasscode.count == upgradeTargetLength
                            ? gradientForLength(upgradeTargetLength)
                            : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }
                    .disabled(upgradePasscode.count != upgradeTargetLength || isUpgrading)
                    
                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .navigationTitle("アップグレード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        showingUpgradeSheet = false
                    }
                }
            }
        }
    }
    
    private var comparisonView: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("現在")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(selectedLength)桁")
                    .font(.headline)
                Text(combinationText(for: selectedLength))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("アップグレード後")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("\(upgradeTargetLength)桁")
                    .font(.headline)
                    .foregroundColor(.orange)
                Text(combinationText(for: upgradeTargetLength))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(16)
        .background(subtleGray)
        .cornerRadius(16)
    }
    
    // MARK: - Helper Methods
    
    private func securityColor(for length: Int) -> Color {
        switch length {
        case 3: return .orange
        case 4: return .yellow
        case 5: return .green
        case 6: return .blue
        case 7: return .purple
        case 8...10: return .pink
        default: return .gray
        }
    }
    
    private func gradientForLength(_ length: Int) -> LinearGradient {
        let color = securityColor(for: length)
        return LinearGradient(
            colors: [color, color.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func combinationText(for length: Int) -> String {
        let count = Int(pow(10.0, Double(length)))
        if count >= 1_000_000_000 { return "100億通り" }
        if count >= 100_000_000 { return "1億通り" }
        if count >= 10_000_000 { return "1,000万通り" }
        if count >= 1_000_000 { return "100万通り" }
        if count >= 100_000 { return "10万通り" }
        if count >= 10_000 { return "1万通り" }
        if count >= 1_000 { return "1,000通り" }
        return "\(count)通り"
    }
    
    // MARK: - Actions
    
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
                passcodeLength: selectedLength
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
        
        do {
            let purchased = try await storeKit.purchase(length: upgradeTargetLength)
            
            guard purchased else {
                return
            }
            
            let result = try await service.upgradePasscodeLength(
                messageId: message.id,
                newLength: upgradeTargetLength,
                newPasscode: upgradePasscode
            )
            
            if result == "success" {
                await MainActor.run {
                    selectedLength = upgradeTargetLength
                    newPasscode = upgradePasscode
                    showingUpgradeSheet = false
                }
                
                rootKeyword = ""
                dismiss()
            } else {
                upgradeError = "アップグレードに失敗しました: \(result)"
            }
        } catch {
            print("Purchase error: \(error)")
            upgradeError = error.localizedDescription
        }
    }
}
