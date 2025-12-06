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
                        // 自分の投稿一覧からは削除可能
                        MessageDetailView(message: message, service: service, allowDelete: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.keyword)
                                .font(.headline)
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
            // ここを追加
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
