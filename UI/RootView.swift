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

    // MARK: - Design Colors & Constants
    // 画像から抽出したカラーパレット
    private let slateBlue = Color(red: 88/255, green: 110/255, blue: 125/255) // "OPEN"の文字色
    private let paperWhite = Color(red: 248/255, green: 248/255, blue: 245/255) // 看板の中身
    private let bgWall = Color(red: 235/255, green: 235/255, blue: 232/255) // 背景の壁色

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景：壁紙のような落ち着いた色
                bgWall.ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // MARK: - 看板風メインカード
                    ZStack {
                        // 1. 白い紙のベース
                        paperWhite
                        
                        // 2. 内側の細い手書き風枠線
                        Rectangle()
                            .stroke(slateBlue, lineWidth: 1.5)
                            .padding(12) // 外枠との隙間
                        
                        // 3. コンテンツ
                        VStack(spacing: 24) {
                            
                            // タイトルロゴ部分
                            VStack(spacing: 8) {
                                Text("AIKOTOBA") // 画像の"OPEN"に合わせて英語表記風に装飾
                                    .font(.system(size: 48, weight: .black, design: .default))
                                    .foregroundColor(slateBlue)
                                    .tracking(2) // 文字間隔を広げる
                                
                                // 下線（筆書き風の線）
                                Capsule()
                                    .fill(slateBlue)
                                    .frame(width: 140, height: 4)
                                    .rotationEffect(.degrees(-1)) // 少し傾けて手書き感
                                
                                Text("please enter keyword") // "please come in" のオマージュ
                                    .font(.custom("SnellRoundhand", size: 24)) // 筆記体フォント（iOS標準）
                                    // 筆記体がない場合のフォールバック
                                    .italic()
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 20)
                            
                            Spacer().frame(height: 10)

                            // 検索フォーム
                            VStack(spacing: 16) {
                                TextField("合言葉", text: $keyword)
                                    .font(.title3)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, 10)
                                    .background(Color.clear)
                                    .overlay(
                                        Rectangle()
                                            .frame(height: 1)
                                            .foregroundColor(slateBlue.opacity(0.5)),
                                        alignment: .bottom
                                    )
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .foregroundColor(slateBlue)

                                Button {
                                    Task { await search() }
                                } label: {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("ENTER")
                                            .font(.headline)
                                            .tracking(1)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? slateBlue.opacity(0.3)
                                    : slateBlue
                                )
                                .foregroundColor(.white)
                                .cornerRadius(0) // 角張らせてクラシックに
                            }
                            .padding(.horizontal, 40)
                            
                            if let errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                    .padding(.bottom, 10)
                            }
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(maxWidth: 350) // カードの幅を制限
                    .aspectRatio(1.3, contentMode: .fit) // 画像のような横長比率に近づける
                    .background(paperWhite)
                    // 外側の太い枠
                    .border(slateBlue, width: 8)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Spacer()
                }
            }
            // ナビゲーションバーの設定（シンプルに）
            .navigationTitle("") // タイトルは非表示にして看板を目立たせる
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 24) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 18))
                                .foregroundColor(slateBlue)
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
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(slateBlue)
                        }
                        
                        NavigationLink {
                            MyMessagesView()
                        } label: {
                            Image(systemName: "person")
                                .font(.system(size: 18))
                                .foregroundColor(slateBlue)
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
            
            // MARK: - Preview Sheet
            .sheet(isPresented: $showingPreviewSheet) {
                if let message = foundMessage {
                    PreviewMessageView(
                        message: message,
                        service: service,
                        rootKeyword: $keyword,
                        isPresented: $showingPreviewSheet
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        } // End NavigationStack
    } // End body

    // MARK: - Functions

    private func search() async {
        errorMessage = nil
        isLoading = true
        foundMessage = nil
        
        defer { isLoading = false }

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            var message = try await service.fetchMessage(by: trimmed)
            
            await MainActor.run {
                if service.isOwner(of: message) {
                    foundMessage = message
                    navigateToFoundMessage = true
                } else {
                    Task {
                        await service.incrementViewCount(for: message.id)
                    }
                    message.view_count += 1
                    foundMessage = message
                    showingPreviewSheet = true
                }
            }
        } catch MessageServiceError.notFound {
            await MainActor.run {
                errorMessage = "Not Found" // 英語の雰囲気に合わせる
            }
        } catch {
            print("検索エラー詳細: \(error)")
            await MainActor.run {
                errorMessage = "Error occurred."
            }
        }
    }
}
