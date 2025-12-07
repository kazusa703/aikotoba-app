import SwiftUI

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
                        
                        Text("暗証番号を入力")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("1日1回のみ挑戦できます。\n正解すると投稿を奪えます。")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // 入力フォーム
                    TextField("番号を入力", text: $inputPasscode)
                        .font(.title)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                        .frame(maxWidth: 200)
                        .disabled(isLoading)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    // 解除ボタン
                    Button {
                        Task { await attemptUnlock() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("解除に挑戦")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(inputPasscode.isEmpty)
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
    
    private func attemptUnlock() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let result = try await service.attemptSteal(messageId: targetMessage.id, guess: inputPasscode)
            
            if result == "success" {
                // 成功！画面を切り替える
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
