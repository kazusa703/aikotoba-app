import SwiftUI

struct MyMessagesView: View {
    @State private var messages: [Message] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedTab: ViewMode = .grid

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
    
    enum ViewMode {
        case grid, list
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Profile Header
                profileHeader
                
                // MARK: - Stats
                statsSection
                
                Divider()
                    .padding(.top, 16)
                
                // MARK: - View Mode Tabs
                viewModeTabs
                
                // MARK: - Content
                if isLoading && messages.isEmpty {
                    loadingView
                } else if let errorMessage, messages.isEmpty {
                    errorView(message: errorMessage)
                } else if messages.isEmpty {
                    emptyView
                } else {
                    switch selectedTab {
                    case .grid:
                        gridView
                    case .list:
                        listView
                    }
                }
            }
        }
        .background(Color.white)
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await loadMessages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.primary)
                }
            }
        }
        .task {
            await loadMessages()
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .stroke(instagramGradient, lineWidth: 3)
                    .frame(width: 90, height: 90)
                
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.gray)
            }
            
            // Name / Info
            VStack(spacing: 4) {
                Text("マイページ")
                    .font(.headline)
                
                Text("あなたの投稿一覧")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack {
            statItem(count: messages.count, label: "投稿")
            
            Divider()
                .frame(height: 40)
            
            statItem(count: myMessages.count, label: "所有中")
            
            Divider()
                .frame(height: 40)
            
            statItem(count: stolenMessages.count, label: "奪われた")
        }
        .padding(.horizontal, 40)
    }
    
    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - View Mode Tabs
    private var viewModeTabs: some View {
        HStack(spacing: 0) {
            tabButton(mode: .grid, icon: "square.grid.3x3")
            tabButton(mode: .list, icon: "list.bullet")
        }
    }
    
    private func tabButton(mode: ViewMode, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = mode
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(selectedTab == mode ? .primary : .secondary)
                
                Rectangle()
                    .fill(selectedTab == mode ? Color.primary : Color.clear)
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Grid View
    private var gridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ], spacing: 2) {
            ForEach(messages) { message in
                NavigationLink {
                    MessageDetailView(message: message, service: service, allowDelete: true)
                } label: {
                    gridCell(message: message)
                }
            }
        }
    }
    
    private func gridCell(message: Message) -> some View {
        ZStack {
            // Background - first image or placeholder
            if let firstImageUrl = message.image_urls?.first,
               let url = URL(string: firstImageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.2)
                }
            } else {
                // Text-only or voice message
                Color.gray.opacity(0.1)
                    .overlay(
                        VStack(spacing: 4) {
                            if message.voice_url != nil {
                                Image(systemName: "waveform")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            } else {
                                Image(systemName: "text.alignleft")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
            
            // Status overlay
            VStack {
                HStack {
                    Spacer()
                    
                    // Multi-image indicator
                    if let urls = message.image_urls, urls.count > 1 {
                        Image(systemName: "square.fill.on.square.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .padding(6)
                    }
                }
                
                Spacer()
                
                HStack {
                    // Stolen indicator
                    if !service.isOwner(of: message) {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("奪われた")
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(4)
                    }
                    
                    // Hidden indicator
                    if message.is_hidden {
                        HStack(spacing: 2) {
                            Image(systemName: "eye.slash")
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
    
    // MARK: - List View
    private var listView: some View {
        LazyVStack(spacing: 0) {
            ForEach(messages) { message in
                NavigationLink {
                    MessageDetailView(message: message, service: service, allowDelete: true)
                } label: {
                    listRow(message: message)
                }
                
                Divider()
                    .padding(.leading, 76)
            }
        }
    }
    
    private func listRow(message: Message) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let firstImageUrl = message.image_urls?.first,
                   let url = URL(string: firstImageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.2)
                    }
                } else {
                    Color.gray.opacity(0.1)
                        .overlay(
                            Image(systemName: message.voice_url != nil ? "waveform" : "text.alignleft")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .clipped()
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.keyword)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // Status badges
                    if !service.isOwner(of: message) {
                        Text("奪われた")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if message.is_hidden {
                        Text("非公開")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Text(message.body.isEmpty ? "（本文なし）" : message.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Stats
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                        Text("\(message.view_count)")
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                        Text("\(message.stolen_count)")
                    }
                    .foregroundColor(.green)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "shield.fill")
                        Text("\(message.failed_count)")
                    }
                    .foregroundColor(.red)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("読み込み中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.title)
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("投稿がありません")
                .font(.headline)
            
            Text("合言葉を作成して\nメッセージを投稿してみましょう")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Computed Properties
    private var myMessages: [Message] {
        messages.filter { service.isOwner(of: $0) }
    }
    
    private var stolenMessages: [Message] {
        messages.filter { !service.isOwner(of: $0) }
    }
    
    // MARK: - Methods
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
                self.errorMessage = "ログインしていません"
            }
        } catch {
            print("fetchMyMessages error: \(error)")
            await MainActor.run {
                self.errorMessage = "読み込みに失敗しました"
            }
        }
    }
}
