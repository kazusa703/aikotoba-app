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
    
    // 未読通知数
    @State private var unreadCount: Int = 0

    private let service = MessageService()

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("aikotoba")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 新規投稿
                        Button {
                            if sessionStore.isGuestMode {
                                showingAuthPrompt = true
                            } else {
                                showingNewMessageSheet = true
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        // お知らせ（バッジ付き）
                        NavigationLink {
                            NotificationsView()
                                .onDisappear {
                                    Task { await loadUnreadCount() }
                                }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.primary)
                                
                                // 未読バッジ
                                if unreadCount > 0 {
                                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(AppColors.error)
                                        .clipShape(Capsule())
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        
                        // マイページ
                        NavigationLink {
                            MyMessagesView()
                        } label: {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppColors.primary)
                        }
                        
                        // 設定・メニュー
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.primary)
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
            // 画面表示時に未読数を取得
            .task {
                await loadUnreadCount()
            }
        }
    }
    
    // MARK: - Load Unread Count
    private func loadUnreadCount() async {
        guard !sessionStore.isGuestMode else {
            unreadCount = 0
            return
        }
        
        do {
            unreadCount = try await service.getUnreadNotificationCount()
        } catch {
            print("Unread count error: \(error)")
        }
    }
    
    // MARK: - Guest Mode Banner
    private var guestModeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.fill.questionmark")
                .foregroundColor(AppColors.warning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ゲストモード")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text("一部機能が制限されています")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
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
                    .background(AppColors.primary)
                    .cornerRadius(12)
            }
        }
        .padding(12)
        .background(AppColors.warning.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.primary)
                
                TextField("合言葉を入力", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: AppColors.primary.opacity(0.08), radius: 8, x: 0, y: 2)
            
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
                    ? AppColors.disabledGradient
                    : AppColors.primaryGradient
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
                .foregroundColor(AppColors.error)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
            
            Text("秘密の合言葉で繋がる")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            Text("合言葉を知っている人だけがアクセスできる\nメッセージを作成・共有しよう")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }
    
    // MARK: - How It Works Section
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使い方")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    howToCard(
                        icon: "plus.circle.fill",
                        title: "作成する",
                        description: "合言葉と暗証番号を設定して投稿",
                        color: AppColors.success
                    )
                    
                    howToCard(
                        icon: "magnifyingglass.circle.fill",
                        title: "検索する",
                        description: "合言葉で投稿を探す",
                        color: AppColors.accent
                    )
                    
                    howToCard(
                        icon: "lock.open.fill",
                        title: "奪う",
                        description: "暗証番号を当てて奪取",
                        color: AppColors.primaryDark
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
                .foregroundColor(AppColors.textPrimary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(width: 140)
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: AppColors.primary.opacity(0.08), radius: 8, x: 0, y: 2)
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
