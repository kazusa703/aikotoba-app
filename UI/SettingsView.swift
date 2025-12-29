import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    // メールアドレス表示用
    @State private var userEmail: String = "読み込み中..."
    
    @State private var showingDeleteAlert = false
    @State private var isLoading = false

    var body: some View {
        List {
            // MARK: - アカウント情報セクション
            Section("アカウント情報") {
                HStack {
                    Text("メールアドレス")
                    Spacer()
                    Text(userEmail)
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - 法的情報セクション
            Section("法的情報") {
                Link(destination: URL(string: "https://kazusa703.github.io/aikotoba-legal/terms.html")!) {
                    HStack {
                        Text("利用規約")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://kazusa703.github.io/aikotoba-legal/privacy.html")!) {
                    HStack {
                        Text("プライバシーポリシー")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // MARK: - ログアウト
            Section {
                Button {
                    Task {
                        await sessionStore.signOut()
                    }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("ログアウト")
                            .foregroundColor(.red)
                    }
                }
            }
            
            // MARK: - アカウント削除
            Section {
                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("アカウント削除")
                            .foregroundColor(.red)
                    }
                }
                .disabled(isLoading)
            } footer: {
                Text("アカウントを削除すると、これまでの投稿データはすべて消去され、復元することはできません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let user = SupabaseClientManager.shared.client.auth.currentUser {
                self.userEmail = user.email ?? "不明"
            } else {
                self.userEmail = "未ログイン"
            }
        }
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
