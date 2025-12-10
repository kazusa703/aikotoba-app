import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    // ★追加: メールアドレス表示用
    @State private var userEmail: String = "読み込み中..."
    
    @State private var showingDeleteAlert = false
    @State private var isLoading = false

    var body: some View {
        List {
            // ★追加: アカウント情報セクション
            Section("アカウント情報") {
                HStack {
                    Text("メールアドレス")
                    Spacer()
                    Text(userEmail)
                        .foregroundColor(.secondary)
                }
            }

            Section("法的情報") {
                // ※URLは後で正しいものに変えてください
                Link("利用規約", destination: URL(string: "https://google.com")!)
                    .foregroundColor(.primary)
                
                Link("プライバシーポリシー", destination: URL(string: "https://google.com")!)
                    .foregroundColor(.primary)
            }
            
            Section {
                Button("ログアウト") {
                    Task {
                        await sessionStore.signOut()
                    }
                }
                .foregroundColor(.red)
            }
            
            Section {
                Button("アカウント削除") {
                    showingDeleteAlert = true
                }
                .foregroundColor(.red)
                .disabled(isLoading)
            } footer: {
                Text("アカウントを削除すると、これまでの投稿データはすべて消去され、復元することはできません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        // ★追加: 画面が表示されたらメールアドレスを取得
        .task {
            if let user = SupabaseClientManager.shared.client.auth.currentUser {
                self.userEmail = user.email ?? "不明"
            } else {
                self.userEmail = "未ログイン"
            }
        }
        // アカウント削除確認アラート
        .alert("アカウント削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除する", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("本当に削除しますか？この操作は取り消せません。")
        }
        // ローディング表示
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("処理中...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // アカウント削除処理
    private func deleteAccount() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await SupabaseClientManager.shared.client
                .database
                .rpc("delete_user")
                .execute()
            
            await sessionStore.signOut()
            
        } catch {
            print("アカウント削除エラー: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SessionStore())
    }
}
