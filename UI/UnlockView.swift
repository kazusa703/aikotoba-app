import SwiftUI
import Combine

struct UnlockView: View {
    @Environment(\.dismiss) private var dismiss
    let service: MessageService
    let targetMessage: Message
    
    @Binding var rootKeyword: String
    @State private var isSuccess = false
    
    @State private var inputPasscode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLimitAlert = false
    
    // Decryption animation
    @State private var isDecrypting = false
    @State private var decodingText = "000"
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
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
        if isSuccess {
            StealSuccessView(
                service: service,
                message: targetMessage,
                rootKeyword: $rootKeyword
            )
        } else {
            NavigationStack {
                ZStack {
                    Color.white.ignoresSafeArea()
                    
                    VStack(spacing: 32) {
                        Spacer()
                        
                        // MARK: - Lock Icon
                        lockIcon
                        
                        // MARK: - Title
                        titleSection
                        
                        // MARK: - Input Section
                        inputSection
                        
                        // MARK: - Submit Button
                        submitButton
                        
                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            rootKeyword = ""
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .alert("挑戦回数終了", isPresented: $showingLimitAlert) {
                    Button("OK") {
                        dismiss()
                    }
                } message: {
                    Text("本日の挑戦回数は終了しました。\nまた明日挑戦してください。")
                }
            }
        }
    }
    
    // MARK: - Lock Icon
    private var lockIcon: some View {
        ZStack {
            // Outer ring with gradient
            Circle()
                .stroke(
                    isDecrypting
                    ? instagramGradient
                    : LinearGradient(colors: [targetMessage.is_4_digit ? .green : .orange], startPoint: .top, endPoint: .bottom),
                    lineWidth: 4
                )
                .frame(width: 120, height: 120)
            
            // Inner circle
            Circle()
                .fill(subtleGray)
                .frame(width: 100, height: 100)
            
            // Icon or animation
            if isDecrypting {
                Text(decodingText)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(instagramGradient)
                    .onReceive(timer) { _ in
                        let digits = targetMessage.is_4_digit ? 4 : 3
                        let maxVal = Int(pow(10.0, Double(digits))) - 1
                        let randomNum = Int.random(in: 0...maxVal)
                        decodingText = String(format: "%0*d", digits, randomNum)
                    }
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(targetMessage.is_4_digit ? .green : .orange)
            }
        }
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(isDecrypting ? "解析中..." : "暗証番号を入力")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("正解するとこの投稿を奪えます")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Security level badge
            HStack(spacing: 4) {
                Image(systemName: targetMessage.is_4_digit ? "lock.shield.fill" : "lock.fill")
                Text(targetMessage.is_4_digit ? "4桁（高難易度）" : "3桁")
            }
            .font(.caption)
            .foregroundColor(targetMessage.is_4_digit ? .green : .orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((targetMessage.is_4_digit ? Color.green : Color.orange).opacity(0.1))
            )
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 16) {
            if !isDecrypting {
                // Passcode input
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.gray)
                    
                    TextField(targetMessage.is_4_digit ? "0000" : "000", text: $inputPasscode)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .disabled(isLoading)
                }
                .padding(16)
                .background(subtleGray)
                .cornerRadius(16)
                
                // Hint
                Text("1日1回のみ挑戦できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Error message
            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button {
            Task { await attemptUnlock() }
        } label: {
            HStack {
                if isLoading || isDecrypting {
                    Text("解析中...")
                } else {
                    Image(systemName: "lock.open.fill")
                    Text("解除に挑戦")
                }
            }
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                inputPasscode.isEmpty || isDecrypting
                ? AnyShapeStyle(Color.gray.opacity(0.3))
                : AnyShapeStyle(instagramGradient)
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(inputPasscode.isEmpty || isDecrypting)
    }
    
    // MARK: - Methods
    private func attemptUnlock() async {
        isLoading = true
        errorMessage = nil
        
        // Start decryption animation
        withAnimation { isDecrypting = true }
        
        // Wait for dramatic effect
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        defer {
            isLoading = false
            withAnimation { isDecrypting = false }
        }
        
        do {
            let result = try await service.attemptSteal(
                messageId: targetMessage.id,
                guess: inputPasscode
            )
            
            if result == "success" {
                // Show correct answer briefly
                decodingText = inputPasscode
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                withAnimation {
                    isSuccess = true
                }
            } else if result == "limit_exceeded" {
                showingLimitAlert = true
            } else {
                errorMessage = "番号が違います"
                inputPasscode = ""
            }
        } catch {
            errorMessage = "エラーが発生しました"
        }
    }
}
