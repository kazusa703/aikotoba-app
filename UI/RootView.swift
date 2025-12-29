import SwiftUI
import Supabase

struct RootView: View {
    @EnvironmentObject var sessionStore: SessionStore
    
    // Search State
    @State private var keyword: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Navigation State
    @State private var foundMessage: Message?
    @State private var navigateToFoundMessage = false
    @State private var showingPreviewSheet = false
    
    @State private var justCreatedMessage: Message?
    @State private var navigateToCreatedMessage = false
    
    // 新規投稿
    @State private var showingNewMessageSheet = false
    
    // 認証促進シート
    @State private var showingAuthPrompt = false

    private let service = MessageService()
    
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
    
    private let disabledGradient = LinearGradient(
        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let subtleGray = Color(red: 250/255, green: 250/255, blue: 250/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ゲストモードバナー
                    if sessionStore.isGuestMode {
                        guestModeBanner
                    }
                    
                    // MARK: - Search Section
                    searchSection
                    
                    // MARK: - Hero Section
                    heroSection
                    
                    // MARK: - How It Works
                    howItWorksSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 20) {
                        // 新規投稿
                        Button {
                            if sessionStore.isGuestMode {
                                showingAuthPrompt = true
                            } else {
                                showingNewMessageSheet = true
                            }
                        } label: {
                            Image(systemName: "plus.app")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                        }
                        
                        // お知らせ
                        NavigationLink {
                            NotificationsView()
                        } label: {
                            Image(systemName: "bell")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                        
                        // マイページ
                        NavigationLink {
                            MyMessagesView()
                        } label: {
                            Image(systemName: "person.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.primary)
                        }
                        
                        // 設定・メニュー
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            // Navigation Destinations
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
            // Preview Sheet
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
            // New Message Sheet
            .sheet(isPresented: $showingNewMessageSheet) {
                NavigationStack {
                    NewMessageView(service: service) { created in
                        justCreatedMessage = created
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            navigateToCreatedMessage = true
                        }
                    }
                }
            }
            // Auth Prompt Sheet
            .sheet(isPresented: $showingAuthPrompt) {
                AuthPromptView(feature: "投稿")
            }
        }
    }
    
    // MARK: - Guest Mode Banner
    private var guestModeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill.questionmark")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ゲストモード")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("一部機能が制限されています")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                showingAuthPrompt = true
            } label: {
                Text("ログイン")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(instagramGradient)
                    .cornerRadius(12)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("合言葉を入力", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(subtleGray)
            .cornerRadius(12)
            
            Button {
                Task { await search() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                        Text("検索")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? disabledGradient
                    : instagramGradient
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            
            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(errorMessage)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(instagramGradient, lineWidth: 3)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(instagramGradient)
            }
            
            Text("秘密の合言葉で繋がる")
                .font(.headline)
            
            Text("合言葉を知っている人だけがアクセスできる\nメッセージを作成・共有しよう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - How It Works Section
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使い方")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    howToCard(
                        icon: "plus.circle.fill",
                        title: "作成する",
                        description: "合言葉と暗証番号を設定して投稿",
                        color: .green
                    )
                    
                    howToCard(
                        icon: "magnifyingglass.circle.fill",
                        title: "検索する",
                        description: "合言葉で投稿を探す",
                        color: .blue
                    )
                    
                    howToCard(
                        icon: "lock.open.fill",
                        title: "奪う",
                        description: "暗証番号を当てて奪取",
                        color: .purple
                    )
                }
            }
        }
    }
    
    private func howToCard(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 140)
        .padding(16)
        .background(subtleGray)
        .cornerRadius(16)
    }
    
    // MARK: - Search Function
    private func search() async {
        errorMessage = nil
        isLoading = true
        foundMessage = nil
        
        defer { isLoading = false }

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let (message, status) = try await service.fetchMessageWithStatus(by: trimmed)
            
            await MainActor.run {
                switch status {
                case "hidden":
                    errorMessage = "この合言葉は現在非公開です"
                case "not_found":
                    errorMessage = "この合言葉は見つかりませんでした"
                default:
                    if var message = message {
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
                }
            }
        } catch {
            print("検索エラー詳細: \(error)")
            await MainActor.run {
                errorMessage = "エラーが発生しました"
            }
        }
    }
}
