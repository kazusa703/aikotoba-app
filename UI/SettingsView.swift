import SwiftUI
import Supabase

struct SettingsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var userEmail: String = "読み込み中..."
    @State private var showingDeleteAlert = false
    @State private var showingLogoutAlert = false
    @State private var isLoading = false
    
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
        List {
            // MARK: - Account Section
            Section {
                HStack(spacing: 16) {
                    // Avatar
                    ZStack {
                        Circle()
                            .stroke(instagramGradient, lineWidth: 2)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("アカウント")
                            .font(.headline)
                        
                        Text(userEmail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // MARK: - About Section
            Section("アプリについて") {
                settingsRow(icon: "doc.text", title: "利用規約", color: .blue) {
                    if let url = URL(string: "https://google.com") {
                        UIApplication.shared.open(url)
                    }
                }
                
                settingsRow(icon: "hand.raised", title: "プライバシーポリシー", color: .green) {
                    if let url = URL(string: "https://google.com") {
                        UIApplication.shared.open(url)
                    }
                }
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.purple)
                        .frame(width: 28)
                    
                    Text("バージョン")
                    
                    Spacer()
                    
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            
            // MARK: - Account Actions
            Section {
                Button {
                    showingLogoutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.orange)
                            .frame(width: 28)
                        
                        Text("ログアウト")
                            .foregroundColor(.primary)
                    }
                }
                
                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .frame(width: 28)
                        
                        Text("アカウント削除")
                            .foregroundColor(.red)
                    }
                }
            } footer: {
                Text("アカウントを削除すると、すべての投稿データが削除され、復元できません。")
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let user = SupabaseClientManager.shared.client.auth.currentUser {
                self.userEmail = user.email ?? "不明"
            } else {
                self.userEmail = "未ログイン"
            }
        }
        // Logout Alert
        .alert("ログアウト", isPresented: $showingLogoutAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("ログアウト", role: .destructive) {
                Task {
                    await sessionStore.signOut()
                }
            }
        } message: {
            Text("ログアウトしますか？")
        }
        // Delete Account Alert
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
        // Loading Overlay
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("処理中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Settings Row
    private func settingsRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 28)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Delete Account
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
