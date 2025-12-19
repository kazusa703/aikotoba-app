import SwiftUI
import Combine

struct UnlockView: View {
    @Environment(\.dismiss) private var dismiss
    let service: MessageService
    let targetMessage: Message
    
    // 親（RootView）の検索ワードを操作するためのBinding
    @Binding var rootKeyword: String
    // 成功したかどうか
    @State private var isSuccess = false
    
    // 入力用
    @State private var inputPasscode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingLimitAlert = false
    
    // ★追加: 労働の錯覚演出用
    @State private var isDecrypting = false
    @State private var decodingText = "000"
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        // 成功したら「成功画面」に切り替える
        if isSuccess {
            StealSuccessView(
                service: service,
                message: targetMessage,
                rootKeyword: $rootKeyword
            )
        } else {
            NavigationStack {
                VStack(spacing: 30) {
                    // 説明
                    VStack(spacing: 10) {
                        Image(systemName: "lock.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(targetMessage.is_4_digit ? .green : .orange)
                        
                        // ★変更: 解析中はテキストを変える
                        Text(isDecrypting ? "解析中..." : "暗証番号を入力")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("1日1回のみ挑戦できます。\n正解すると投稿を奪えます。")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // ★変更: 入力フォームエリア
                    ZStack {
                        if isDecrypting {
                            // 労働の錯覚: ランダムな数字がパラパラ動く演出
                            Text(decodingText)
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                                .onReceive(timer) { _ in
                                    // ランダムな3桁or4桁を表示
                                    let digits = targetMessage.is_4_digit ? 4 : 3
                                    let randomNum = Int.random(in: 0...Int(pow(10.0, Double(digits)))-1)
                                    decodingText = String(format: "%0*d", digits, randomNum)
                                }
                        } else {
                            // 通常の入力フォーム
                            TextField("番号を入力", text: $inputPasscode)
                                .font(.title)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(12)
                                .frame(maxWidth: 200)
                                .disabled(isLoading)
                        }
                    }
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    // ★変更: 解除ボタン
                    Button {
                        Task { await attemptUnlock() }
                    } label: {
                        if isLoading || isDecrypting {
                            // ★変更: 解析中はインジケーターではなくテキスト
                            Text("解析進行中...")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("解除に挑戦")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(inputPasscode.isEmpty || isDecrypting) // 解析中は押せない
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // 左: 戻る（プレビューに戻る）
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("＜") {
                            dismiss()
                        }
                    }
                    // 右: ×（検索画面に戻り、検索ワードを消す）
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            rootKeyword = "" // ★B案: 検索ワードを消す
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .alert("挑戦回数終了", isPresented: $showingLimitAlert) {
                    Button("OK") {
                        // rootKeyword = ""  ← これを消します（検索ワードを消さない）
                        dismiss() // UnlockView だけを閉じてプレビューに戻る
                    }
                } message: {
                    Text("本日の挑戦回数は終了しました。\nまた明日挑戦してください。")
                }
            }
        }
    }
    
    // ★変更: attemptUnlock に労働の錯覚演出を追加
    private func attemptUnlock() async {
        isLoading = true
        errorMessage = nil
        
        // ★追加: 労働の錯覚（あえて待たせる）
        withAnimation { isDecrypting = true }
        
        // 2秒間待たせる（ユーザーに「計算している」と思わせる）
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        defer {
            isLoading = false
            withAnimation { isDecrypting = false }
        }
        
        do {
            let result = try await service.attemptSteal(messageId: targetMessage.id, guess: inputPasscode)
            
            if result == "success" {
                // 成功！
                // ★追加: 成功時は入力した正解番号を表示してから遷移
                decodingText = inputPasscode
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒余韻
                
                withAnimation {
                    isSuccess = true
                }
            } else if result == "limit_exceeded" {
                showingLimitAlert = true
            } else {
                errorMessage = "番号が違います..."
                inputPasscode = ""
            }
        } catch {
            errorMessage = "エラーが発生しました。"
        }
    }
}
