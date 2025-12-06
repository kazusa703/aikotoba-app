import SwiftUI
import Supabase

struct RootView: View {
    @State private var keyword: String = ""
    @State private var foundMessage: Message?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 修正1: 一覧ではなく「投稿した直後のメッセージ」を保存する変数を用意
    @State private var justCreatedMessage: Message?
    // 修正2: 詳細画面へ遷移するためのフラグ
    @State private var navigateToDetail = false

    private let service = MessageService()
    
    private var client: SupabaseClient {
        SupabaseClientManager.shared.client
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
                    HStack {
                        NavigationLink {
                            // 投稿画面へ遷移
                            NewMessageView(service: service) { created in
                                // 修正3: 作成されたメッセージを保存し、少し待ってから遷移フラグをON
                                justCreatedMessage = created
                                Task {
                                    // 画面が閉じるアニメーションを少し待つ
                                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
                                    navigateToDetail = true
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
            // 検索結果のシート表示
            .sheet(item: $foundMessage) { message in
                NavigationStack {
                    MessageDetailView(message: message, service: service, allowDelete: false)
                }
            }
            // 修正4: フラグが true になったら、保存しておいたメッセージの詳細画面へ飛ぶ
            .navigationDestination(isPresented: $navigateToDetail) {
                if let message = justCreatedMessage {
                    // 自分の投稿なので allowDelete は true
                    MessageDetailView(message: message, service: service, allowDelete: true)
                }
            }
        }
    }

    private func search() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let message = try await service.fetchMessage(by: trimmed)
            await MainActor.run {
                foundMessage = message
            }
        } catch MessageServiceError.notFound {
            await MainActor.run {
                errorMessage = "この合言葉のメッセージはまだありません。"
            }
        } catch {
            await MainActor.run {
                errorMessage = "エラーが発生しました。時間をおいて再度お試しください。"
            }
        }
    }
}
