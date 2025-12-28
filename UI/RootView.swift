import SwiftUI
import Supabase

struct RootView: View {
    @EnvironmentObject var sessionStore: SessionStore
    
    // MARK: - Search State
    @State private var keyword: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isHiddenMessage = false  // ★追加: 非公開フラグ
    
    // MARK: - Navigation State
    @State private var foundMessage: Message?
    @State private var navigateToFoundMessage = false
    @State private var showingPreviewSheet = false
    
    // 新規作成時用
    @State private var justCreatedMessage: Message?
    @State private var navigateToCreatedMessage = false
    
    // 通知シート
    @State private var showingNotifications = false

    private let service = MessageService()
    
    // MARK: - Instagram Colors
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
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Custom Header
                    headerView
                    
                    Divider()
                    
                    // MARK: - Search Section
                    searchSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                    
                    // MARK: - Main Content
                    ScrollView {
                        VStack(spacing: 24) {
                            heroSection
                                .padding(.top, 20)
                            
                            howItWorksSection
                            
                            Spacer(minLength: 100)
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsView()
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("aikotoba")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .italic()
            
            Spacer()
            
            HStack(spacing: 20) {
                NavigationLink {
                    NewMessageView(service: service) { created in
                        justCreatedMessage = created
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            navigateToCreatedMessage = true
                        }
                    }
                } label: {
                    Image(systemName: "plus.app")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
                
                Button {
                    showingNotifications = true
                } label: {
                    Image(systemName: "heart")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
                
                NavigationLink {
                    MyMessagesView()
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
                
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("合言葉を入力", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: keyword) { _, _ in
                        // 入力が変わったらエラーをクリア
                        errorMessage = nil
                        isHiddenMessage = false
                    }
                
                if !keyword.isEmpty {
                    Button {
                        keyword = ""
                        errorMessage = nil
                        isHiddenMessage = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(subtleGray)
            .cornerRadius(12)
            
            // Search Button
            Button {
                Task { await search() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("検索")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AnyShapeStyle(Color.gray.opacity(0.3))
                        : AnyShapeStyle(instagramGradient)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    }
            .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            
            // Error Message
            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: isHiddenMessage ? "eye.slash.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isHiddenMessage ? .orange : .red)
                    
                    Text(errorMessage)
                        .foregroundColor(isHiddenMessage ? .orange : .red)
                }
                .font(.caption)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(instagramGradient, lineWidth: 3)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundStyle(instagramGradient)
            }
            
            VStack(spacing: 8) {
                Text("秘密の合言葉")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("合言葉を知っている人だけが\nメッセージを見られる")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - How It Works Section
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使い方")
                .font(.headline)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    featureCard(
                        icon: "pencil.circle.fill",
                        title: "作成",
                        description: "合言葉を設定して\nメッセージを投稿",
                        color: .purple
                    )
                    
                    featureCard(
                        icon: "magnifyingglass.circle.fill",
                        title: "検索",
                        description: "合言葉を入力して\nメッセージを探す",
                        color: .pink
                    )
                    
                    featureCard(
                        icon: "lock.circle.fill",
                        title: "奪取",
                        description: "暗証番号を当てて\n投稿を奪う",
                        color: .orange
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func featureCard(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(width: 140, alignment: .leading)
        .padding(16)
        .background(subtleGray)
        .cornerRadius(16)
    }

    // MARK: - Search Function
    private func search() async {
        errorMessage = nil
        isHiddenMessage = false
        isLoading = true
        foundMessage = nil
        
        defer { isLoading = false }

        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            // ★新しいメソッドを使用（非公開チェック込み）
            let message = try await service.fetchMessageWithStatus(by: trimmed)
            
            await MainActor.run {
                if service.isOwner(of: message) {
                    foundMessage = message
                    navigateToFoundMessage = true
                } else {
                    Task {
                        await service.incrementViewCount(for: message.id)
                    }
                    var updatedMessage = message
                    updatedMessage.view_count += 1
                    foundMessage = updatedMessage
                    showingPreviewSheet = true
                }
            }
        } catch MessageServiceError.hidden {
            // ★非公開の場合
            await MainActor.run {
                isHiddenMessage = true
                errorMessage = "この合言葉は現在非公開です"
            }
        } catch MessageServiceError.notFound {
            await MainActor.run {
                errorMessage = "この合言葉は見つかりませんでした"
            }
        } catch {
            print("検索エラー詳細: \(error)")
            await MainActor.run {
                errorMessage = "エラーが発生しました"
            }
        }
    }
}
