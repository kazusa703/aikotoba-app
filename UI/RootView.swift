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
    @State private var navigateToFoundMessage = false
    @State private var showingPreviewSheet = false
    
    @State private var justCreatedMessage: Message?
    @State private var navigateToCreatedMessage = false
    
    // MARK: - Unlock / Steal State
    @State private var showingUnlockAlert = false
    @State private var unlockInput = ""
    @State private var unlockMessageId: UUID?
    @State private var unlockErrorMessage: String?

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
            
            // MARK: - Preview Sheet (他人の投稿)
            .sheet(isPresented: $showingPreviewSheet) {
                if let message = foundMessage {
                    VStack(spacing: 24) {
                        // ハンドルバー
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
                        
                        // 内容（スクロール可能に）
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
                            unlockInput = ""
                            unlockMessageId = message.id
                            unlockErrorMessage = nil
                            showingUnlockAlert = true
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
                    .presentationDetents([.medium, .large])
                }
            }
            
            // MARK: - Unlock Alert
            .alert("暗証番号を入力", isPresented: $showingUnlockAlert) {
                TextField("番号", text: $unlockInput)
                    .keyboardType(.numberPad)
                Button("キャンセル", role: .cancel) { }
                Button("解除に挑戦") {
                    Task {
                        await attemptUnlock()
                    }
                }
            } message: {
                if let err = unlockErrorMessage {
                    Text(err)
                } else {
                    Text("1日1回のみ挑戦できます。\n正解すると投稿を奪えます。")
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
            let message = try await service.fetchMessage(by: trimmed)
            
            await MainActor.run {
                foundMessage = message
                
                // 所有権チェックで動きを分岐
                if service.isOwner(of: message) {
                    // 自分の投稿なら → 詳細画面へ移動
                    navigateToFoundMessage = true
                } else {
                    // 他人の投稿なら → 下からシートを表示
                    showingPreviewSheet = true
                }
            }
        } catch MessageServiceError.notFound {
                    await MainActor.run { errorMessage = "見つかりません（または隠されています）" }
                } catch {
                    // ★追加: エラーの正体をコンソールに出す
                    print("==========================================")
                    print("検索エラー詳細: \(error)")
                    print("==========================================")
                    
                    await MainActor.run { errorMessage = "エラーが発生しました" }
                }
            }
    
    // ロック解除（奪う）処理
    private func attemptUnlock() async {
        guard let messageId = unlockMessageId else { return }
        unlockErrorMessage = nil
        
        do {
            let result = try await service.attemptSteal(messageId: messageId, guess: unlockInput)
            
            await MainActor.run {
                if result == "success" {
                    // 成功したらシートを閉じる
                    showingPreviewSheet = false
                    foundMessage = nil
                    unlockInput = ""
                    showingUnlockAlert = false
                } else if result == "limit_exceeded" {
                    unlockErrorMessage = "本日の挑戦回数は終了しました。"
                    showingUnlockAlert = true
                } else {
                    unlockErrorMessage = "番号が違います..."
                    showingUnlockAlert = true
                }
            }
        } catch {
            await MainActor.run {
                unlockErrorMessage = "エラーが発生しました。"
                showingUnlockAlert = true
            }
        }
    }
}
