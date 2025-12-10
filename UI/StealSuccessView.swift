import SwiftUI

struct StealSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    let service: MessageService
    let message: Message
    
    @Binding var rootKeyword: String
    
    @State private var newPasscode = ""
    @State private var isLoading = false
    @State private var showingAutoSetAlert = false // 自動設定の通知用

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            Text("奪取成功！\nあなたのものになりました")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("新しい暗証番号を設定してください")
                    .font(.headline)
                
                // ★A案: 4桁だった場合は4桁を引き継げる
                if message.is_4_digit {
                    Text("🔒 4桁モードを引き継ぎました")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("3桁（000〜999）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextField("番号を入力", text: $newPasscode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .onChange(of: newPasscode) { _, val in
                        let limit = message.is_4_digit ? 4 : 3
                        if val.count > limit { newPasscode = String(val.prefix(limit)) }
                    }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button {
                Task { await updatePasscode() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("設定して公開する")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(newPasscode.isEmpty)
            .padding(.horizontal, 40)
            
            Spacer()
            
            // 設定せずに閉じるボタン
            Button("後で設定する（現在は非公開）") {
                showingAutoSetAlert = true
            }
            .foregroundColor(.secondary)
            .padding(.bottom)
        }
        // ★自動設定の通知アラート（修正）
                .alert("設定は未完了です", isPresented: $showingAutoSetAlert) {
                    Button("わかった") { // ボタン名を「OK」から変更（ニュアンス調整）
                        rootKeyword = ""
                        dismiss()
                    }
                } message: {
                    // ★ここを書き換え
                    Text("""
                    暗証番号は一時的に「000」に設定され、投稿は「非公開」になりました。
                    
                    ⚠️ 重要 ⚠️
                    24時間以内に「自分の投稿」から編集して再公開しない場合、この投稿は【自動的に削除】され、合言葉の権利を失います。
                    """)
                }
        .interactiveDismissDisabled() // スワイプで閉じられないようにする
    }
    
    private func updatePasscode() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // パスコードを更新して再公開(is_hidden=false)する
            // 既存の画像やボイスはそのまま維持するために引数を渡す
            _ = try await service.updateMessage(
                message: message,
                keyword: message.keyword, // 合言葉はそのまま
                body: message.body,       // 本文もそのまま
                shouldDeleteVoice: false,
                newVoiceData: nil,
                remainingImageUrls: message.image_urls ?? [],
                newImagesData: [],
                passcode: newPasscode,
                is4Digit: message.is_4_digit // モード引き継ぎ
            )
            
            // 完了したら戻る
            rootKeyword = ""
            dismiss()
            
        } catch {
            print("Update error: \(error)")
        }
    }
}
