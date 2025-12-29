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
    
    // Hint display
    @State private var hints: [HintResult] = []
    @State private var showHints = false
    
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
    
    private var passcodeLength: Int {
        targetMessage.passcode_length
    }
    
    enum HintResult {
        case exact      // ◎
        case partial    // ○
        case wrong      // ×
        
        var symbol: String {
            switch self {
            case .exact: return "◎"
            case .partial: return "○"
            case .wrong: return "×"
            }
        }
        
        var color: Color {
            switch self {
            case .exact: return .green
            case .partial: return .orange
            case .wrong: return .red
            }
        }
    }

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
                        
                        lockIcon
                        titleSection
                        
                        if showHints && !hints.isEmpty {
                            hintsDisplay
                        }
                        
                        inputSection
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
                    Button("OK") { dismiss() }
                } message: {
                    Text("本日の挑戦回数は終了しました。\nまた明日挑戦してください。")
                }
            }
        }
    }
    
    // MARK: - Lock Icon
    private var lockIcon: some View {
        ZStack {
            Circle()
                .stroke(
                    isDecrypting
                    ? instagramGradient
                    : LinearGradient(colors: [securityColor], startPoint: .top, endPoint: .bottom),
                    lineWidth: 4
                )
                .frame(width: 120, height: 120)
            
            Circle()
                .fill(subtleGray)
                .frame(width: 100, height: 100)
            
            if isDecrypting {
                Text(decodingText)
                    .font(.system(size: passcodeLength > 6 ? 20 : 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(instagramGradient)
                    .onReceive(timer) { _ in
                        let maxVal = Int(pow(10.0, Double(passcodeLength))) - 1
                        let randomNum = Int.random(in: 0...maxVal)
                        decodingText = String(format: "%0*d", passcodeLength, randomNum)
                    }
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(securityColor)
            }
        }
    }
    
    private var securityColor: Color {
        switch passcodeLength {
        case 3: return .orange
        case 4: return .yellow
        case 5: return .green
        case 6: return .blue
        case 7: return .purple
        case 8...10: return .pink
        default: return .gray
        }
    }
    
    // MARK: - Title
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(isDecrypting ? "解析中..." : "暗証番号を入力")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("正解するとこの投稿を奪えます")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: securityIcon)
                Text("\(passcodeLength)桁" + difficultyText)
            }
            .font(.caption)
            .foregroundColor(securityColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(securityColor.opacity(0.1))
            )
        }
    }
    
    private var securityIcon: String {
        switch passcodeLength {
        case 3: return "lock.fill"
        case 4...5: return "lock.shield.fill"
        case 6...7: return "shield.fill"
        case 8...10: return "shield.checkered"
        default: return "lock.fill"
        }
    }
    
    private var difficultyText: String {
        switch passcodeLength {
        case 3: return ""
        case 4: return "（やや難）"
        case 5: return "（難）"
        case 6: return "（高難度）"
        case 7: return "（超難）"
        case 8...10: return "（極難）"
        default: return ""
        }
    }
    
    // MARK: - Hints Display
    private var hintsDisplay: some View {
        VStack(spacing: 12) {
            Text("結果")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 桁数が多い場合は折り返し
            let columns = passcodeLength <= 6 ? passcodeLength : 5
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(hints.indices, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text(hints[index].symbol)
                            .font(.system(size: passcodeLength > 6 ? 24 : 32, weight: .bold))
                            .foregroundColor(hints[index].color)
                        
                        if index < inputPasscode.count {
                            let digitIndex = inputPasscode.index(inputPasscode.startIndex, offsetBy: index)
                            Text(String(inputPasscode[digitIndex]))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 44, height: 55)
                    .background(hints[index].color.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            // Legend
            VStack(alignment: .leading, spacing: 4) {
                legendRow(symbol: "◎", text: "数字と位置が一致", color: .green)
                legendRow(symbol: "○", text: "数字は合っているが位置が違う", color: .orange)
                legendRow(symbol: "×", text: "この数字は含まれていない", color: .red)
            }
            .font(.caption)
            .padding(.top, 8)
        }
        .padding(16)
        .background(subtleGray)
        .cornerRadius(16)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
    
    private func legendRow(symbol: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(symbol)
                .foregroundColor(color)
                .fontWeight(.bold)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 16) {
            if !isDecrypting {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.gray)
                    
                    TextField(String(repeating: "0", count: passcodeLength), text: $inputPasscode)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .disabled(isLoading)
                        .onChange(of: inputPasscode) { _, newValue in
                            if showHints {
                                withAnimation {
                                    showHints = false
                                    hints = []
                                }
                            }
                            if newValue.count > passcodeLength {
                                inputPasscode = String(newValue.prefix(passcodeLength))
                            }
                        }
                }
                .padding(16)
                .background(subtleGray)
                .cornerRadius(16)
                
                Text("1日1回のみ挑戦できます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let errorMessage, !showHints {
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
                inputPasscode.count != passcodeLength || isDecrypting
                ? AnyShapeStyle(Color.gray.opacity(0.3))
                : AnyShapeStyle(instagramGradient)
            )
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(inputPasscode.count != passcodeLength || isDecrypting)
    }
    
    // MARK: - Methods
    private func attemptUnlock() async {
        isLoading = true
        errorMessage = nil
        
        let attemptedPasscode = inputPasscode
        
        withAnimation { isDecrypting = true }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        defer {
            isLoading = false
            withAnimation { isDecrypting = false }
        }
        
        do {
            let result = try await service.attemptSteal(
                messageId: targetMessage.id,
                guess: attemptedPasscode
            )
            
            if result == "success" {
                decodingText = attemptedPasscode
                try? await Task.sleep(nanoseconds: 500_000_000)
                withAnimation { isSuccess = true }
                
            } else if result == "limit_exceeded" {
                showingLimitAlert = true
                
            } else if result.hasPrefix("failed:") {
                let hintString = String(result.dropFirst(7))
                parseHints(from: hintString, attemptedPasscode: attemptedPasscode)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showHints = true
                }
            } else {
                errorMessage = "番号が違います"
                inputPasscode = ""
            }
        } catch {
            errorMessage = "エラーが発生しました"
        }
    }
    
    private func parseHints(from hintString: String, attemptedPasscode: String) {
        hints = []
        
        for char in hintString {
            switch char {
            case "◎": hints.append(.exact)
            case "○": hints.append(.partial)
            case "×": hints.append(.wrong)
            default: break
            }
        }
        
        if hints.isEmpty {
            hints = Array(repeating: .wrong, count: passcodeLength)
        }
        
        inputPasscode = attemptedPasscode
    }
}
