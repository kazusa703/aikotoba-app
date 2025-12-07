import SwiftUI

struct PreviewMessageView: View {
    // データ受け取り用
    let message: Message
    let service: MessageService
    
    // RootViewの状態を操作するためのBinding
    @Binding var rootKeyword: String // 検索ワード（成功時に消すため）
    @Binding var isPresented: Bool   // この画面を閉じるため
    
    // 奪う画面の表示フラグ
    @State private var showingUnlockView = false

    var body: some View {
        VStack(spacing: 24) {
            // ハンドルバー（シートの持ち手）
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            // 題名
            Text(message.keyword)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // 閲覧数
            HStack {
                Image(systemName: "eye.fill")
                Text("\(message.view_count)")
            }
            .foregroundColor(.secondary)
            .font(.subheadline)
            
            Divider()
            
            // 内容（スクロール可能）
            ScrollView {
                Text(message.body)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: 200)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            
            Divider()
            
            // 奪うボタン（鍵マーク）
            Button {
                showingUnlockView = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(message.is_4_digit ? .green : .orange)
                    
                    Text("この投稿を奪う")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(message.is_4_digit ? "4桁の暗証番号" : "3桁の暗証番号")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(uiColor: .systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(message.is_4_digit ? Color.green : Color.orange, lineWidth: 2)
                )
            }
            
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large]) // シートの高さ設定
        // ★この画面の上から「奪う画面」を出す
        .fullScreenCover(isPresented: $showingUnlockView) {
            UnlockView(
                service: service,
                targetMessage: message,
                rootKeyword: $rootKeyword
            )
            .onDisappear {
                // 奪取成功または×ボタンで戻ってきた時、
                // 検索ワードが空になっていたら、このプレビュー画面も閉じる
                if rootKeyword.isEmpty {
                    isPresented = false
                }
            }
        }
    }
}
