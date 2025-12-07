import SwiftUI
import Supabase

struct RootView: View {
    @EnvironmentObject var sessionStore: SessionStore
    
    // MARK: - Search State
    @State private var keyword: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // MARK: - Navigation State
    @State private var foundMessage: Message?
    
    // 1. 自分の投稿 → 詳細画面へ遷移
    @State private var navigateToFoundMessage = false
    
    // 2. 他人の投稿 → プレビューシートを表示
    @State private var showingPreviewSheet = false
    
    // 新規作成時用
    @State private var justCreatedMessage: Message?
    @State private var navigateToCreatedMessage = false

    private let service = MessageService()
    
    private var client: SupabaseClient {
        SupabaseClientManager.shared.client
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 検索フォーム
                TextField("合言葉を入力", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal)

                Button {
                    Task { await search() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("検索")
                    }
                }
                .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                // エラーメッセージ表示
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("あいことば")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 20) {
                        
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.primary)
                        }

                        NavigationLink {
                            NewMessageView(service: service) { created in
                                justCreatedMessage = created
                                Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    navigateToCreatedMessage = true
                                }
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        
                        NavigationLink {
                            MyMessagesView()
                        } label: {
                            Image(systemName: "person.fill")
                        }
                    }
                }
            }
            // MARK: - Navigation Destinations
            
            .navigationDestination(isPresented: $navigateToFoundMessage) {
                if let message = foundMessage {
                    MessageDetailView(message: message, service: service, allowDelete: false)
                }
            }
            
            .navigationDestination(isPresented: $navigateToCreatedMessage) {
                if let message = justCreatedMessage {
                    MessageDetailView(message: message, service: service, allowDelete: true)
                }
            }
            
            // ★修正: 他人の投稿が見つかった時のシート
            // 中身を新しい PreviewMessageView に置き換えました
            .sheet(isPresented: $showingPreviewSheet) {
                if let message = foundMessage {
                    PreviewMessageView(
                        message: message,
                        service: service,
                        rootKeyword: $keyword,
                        isPresented: $showingPreviewSheet
                    )
                }
            }
        }
    }

    // MARK: - Functions

    private func search() async {
        errorMessage = nil
        isLoading = true
        foundMessage = nil
        
        defer { isLoading = false }

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            // ★変更: view_count を書き換えるため var に変更
            var message = try await service.fetchMessage(by: trimmed)
            
            await MainActor.run {
                if service.isOwner(of: message) {
                    foundMessage = message
                    navigateToFoundMessage = true
                } else {
                    // ★追加: 他人の投稿ならここで閲覧数をカウントアップ
                    Task {
                        await service.incrementViewCount(for: message.id)
                    }
                    // ★追加: 表示上の数字も増やしておく（リアルタイム反映）
                    message.view_count += 1
                    foundMessage = message
                    
                    showingPreviewSheet = true
                }
            }
        } catch MessageServiceError.notFound {
            await MainActor.run {
                errorMessage = "見つかりません（または隠されています）"
            }
        } catch {
            await MainActor.run {
                errorMessage = "エラーが発生しました。時間をおいて再度お試しください。"
            }
        }
    }
    
    
    // MARK: - Unused (削除可能)
    // attemptUnlock メソッドは不要になったため削除
}
