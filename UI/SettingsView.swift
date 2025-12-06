import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    // 削除確認アラート用のフラグ
    @State private var showingDeleteAlert = false
    @State private var isLoading = false

    var body: some View {
        List {
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
                .foregroundColor(.red) // ログアウトも少し目立たせる（お好みで）
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
        // ローディング表示（削除処理中）
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
            // ステップ1で作ったSupabaseの関数 'delete_user' を呼び出す
            try await SupabaseClientManager.shared.client
                .rpc("delete_user")
                .execute()
            
            // 成功したらアプリ側もログアウト状態にする
            await sessionStore.signOut()
            
        } catch {
            print("アカウント削除エラー: \(error)")
            // エラーが発生した場合の処理（必要ならアラートを出すなど）
        }
    }
    }

    #Preview {
        NavigationStack {
            SettingsView()
                .environmentObject(SessionStore())
        }
    }
