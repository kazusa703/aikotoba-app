import SwiftUI

struct MyMessagesView: View {
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = MessageService()

    var body: some View {
        List {
            if isLoading && messages.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let errorMessage, messages.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else if messages.isEmpty {
                Text("まだ投稿はありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(messages) { message in
                    NavigationLink {
                        // 自分の投稿一覧からは削除可能（ただし奪われたものは削除できないように詳細画面で制御済み）
                        MessageDetailView(message: message, service: service, allowDelete: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            // タイトル行（合言葉 + アイコン）
                            HStack {
                                Text(message.keyword)
                                    .font(.headline)
                                
                                // ★状態に応じたアイコン表示
                                if service.isOwner(of: message) {
                                    // 1. 自分のもの
                                    if message.is_hidden {
                                        // 設定待ち（非公開）→ ⚠️
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.yellow)
                                        Text("設定待ち")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    // 2. 他人のもの（奪われた）→ 🚫
                                    Image(systemName: "person.fill.xmark")
                                        .foregroundColor(.red)
                                    Text("奪われました")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            // 本文
                            Text(message.body)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("自分の投稿")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await loadMessages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await loadMessages()
        }
    }

    private func loadMessages() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await service.fetchMyMessages()
            await MainActor.run {
                self.messages = result
            }
        } catch MessageServiceError.notSignedIn {
            await MainActor.run {
                self.errorMessage = "ログインしていません。"
            }
        } catch {
            print("fetchMyMessages error: \(error)")
            await MainActor.run {
                self.errorMessage = "読み込みに失敗しました。時間をおいて再度お試しください。"
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let message = messages[index]
                // 自分のものだけ削除可能にする
                guard service.isOwner(of: message) else { continue }
                
                do {
                    try await service.deleteMessage(message)
                } catch {
                    print("削除に失敗: \(error)")
                }
            }
            await loadMessages()
        }
    }
}
