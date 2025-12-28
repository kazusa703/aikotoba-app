import SwiftUI

struct StealSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let service: MessageService
    let message: Message
    
    @Binding var rootKeyword: String
    
    @State private var newPasscode = ""
    @State private var isLoading = false
    @State private var showingAutoSetAlert = false
    @State private var showConfetti = true
    
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

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            // Confetti effect (simple version)
            if showConfetti {
                confettiOverlay
            }
            
            VStack(spacing: 32) {
                Spacer()
                
                // MARK: - Success Icon
                successIcon
                
                // MARK: - Title
                titleSection
                
                // MARK: - Passcode Input
                passcodeSection
                
                // MARK: - Submit Button
                submitButton
                
                // MARK: - Skip Button
                skipButton
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .alert("設定未完了", isPresented: $showingAutoSetAlert) {
            Button("確認") {
                rootKeyword = ""
                dismiss()
            }
        } message: {
            Text("暗証番号は「000」に設定され、投稿は「非公開」になりました。\n\n24時間以内に編集して再公開しないと自動削除されます。")
        }
        .interactiveDismissDisabled()
        .onAppear {
            // Auto-hide confetti after 3 seconds
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
            
            // Keyword badge
            Text(message.keyword)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(instagramGradient)
                .cornerRadius(20)
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
                    Text(message.is_4_digit ? "4桁モード" : "3桁モード")
                }
                .font(.caption)
                .foregroundColor(message.is_4_digit ? .green : .orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((message.is_4_digit ? Color.green : Color.orange).opacity(0.1))
                )
            }
            
            // Input
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.gray)
                
                TextField(message.is_4_digit ? "新しい4桁番号" : "新しい3桁番号", text: $newPasscode)
                    .keyboardType(.numberPad)
                    .font(.title3)
            }
            .padding(16)
            .background(subtleGray)
            .cornerRadius(16)
            .onChange(of: newPasscode) { _, val in
                let limit = message.is_4_digit ? 4 : 3
                if val.count > limit {
                    newPasscode = String(val.prefix(limit))
                }
            }
            
            // Hint
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
            .fontWeight(.bold)
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
                is4Digit: message.is_4_digit
            )
            
            rootKeyword = ""
            dismiss()
            
        } catch {
            print("Update error: \(error)")
        }
    }
}
