import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    // メールアドレス表示用
    @State private var userEmail: String = "読み込み中..."
    
    @State private var showingLogoutAlert = false
    @State private var showingDeleteAlert = false
    @State private var isLoading = false
    @State private var showingAuthPrompt = false
    
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

    var body: some View {
        List {
            // MARK: - ゲストモードの場合
            if sessionStore.isGuestMode {
                Section {
                    Button {
                        showingAuthPrompt = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(instagramGradient)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ログイン / 新規登録")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("すべての機能を使えるようになります")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("アカウント")
                } footer: {
                    Text("ゲストモードでは投稿の作成・奪取ができません")
                }
            } else {
                // MARK: - アカウント情報セクション（ログイン時）
                Section("アカウント情報") {
                    HStack {
                        Text("メールアドレス")
                        Spacer()
                        Text(userEmail)
                            .foregroundColor(.secondary)
                    }
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
            
            // MARK: - ログアウト（ログイン時のみ）
            if !sessionStore.isGuestMode {
                Section {
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.orange)
                            Text("ログアウト")
                                .foregroundColor(.orange)
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
            } else {
                // ゲストモード終了
                Section {
                    Button {
                        sessionStore.exitGuestMode()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left.circle")
                                .foregroundColor(.secondary)
                            Text("ログイン画面に戻る")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !sessionStore.isGuestMode {
                if let user = SupabaseClientManager.shared.client.auth.currentUser {
                    self.userEmail = user.email ?? "不明"
                } else {
                    self.userEmail = "未ログイン"
                }
            }
        }
        // ログアウト確認アラート
        .alert("ログアウト", isPresented: $showingLogoutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                Task {
                    await sessionStore.signOut()
                }
            }
        } message: {
            Text("本当にログアウトしますか？")
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
            Text("本当に削除しますか？この操作は取り消せません。投稿データもすべて削除されます。")
        }
        .sheet(isPresented: $showingAuthPrompt) {
            AuthPromptView(feature: "アカウント作成")
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
