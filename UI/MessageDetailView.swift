import SwiftUI
import AVFoundation

struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayingMessage: Message
    let service: MessageService
    let allowDelete: Bool

    // Action States
    @State private var isReporting = false
    @State private var isDeleting = false
    @State private var infoMessage: String?
    
    // Alert States
    @State private var showingDeleteAlert = false
    @State private var showingCopyAlert = false
    @State private var isPresentingEditSheet = false
    
    // Audio States
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false
    
    // Unlock State
    @State private var showingUnlockView = false
    @State private var currentImageIndex = 0
    
    // Tooltip states
    @State private var showViewTooltip = false
    @State private var showChallengeTooltip = false
    @State private var showDefenseTooltip = false
    @State private var showStolenTooltip = false
    
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
    
    private let goldGradient = LinearGradient(
        colors: [
            Color(red: 255/255, green: 215/255, blue: 0/255),
            Color(red: 255/255, green: 193/255, blue: 37/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let subtleGray = Color(red: 250/255, green: 250/255, blue: 250/255)
    
    private var isOwner: Bool {
        service.isOwner(of: displayingMessage)
    }

    init(message: Message, service: MessageService, allowDelete: Bool) {
        _displayingMessage = State(initialValue: message)
        self.service = service
        self.allowDelete = allowDelete
    }

    var body: some View {
        ZStack {
            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Header
                    if isOwner {
                        ownerHeaderSection
                    } else {
                        visitorHeaderSection
                    }
                    
                    // MARK: - Stats Dashboard (Owner Only - Large)
                    if isOwner {
                        statsDashboard
                    }
                    
                    // MARK: - Image Carousel
                    if let urls = displayingMessage.image_urls, !urls.isEmpty {
                        imageCarousel(urls: urls)
                    }
                    
                    // MARK: - Stats Bar (Visitor Only - with tooltips)
                    if !isOwner {
                        visitorStatsBar
                    }
                    
                    // MARK: - Hidden Warning (Owner Only)
                    if isOwner && displayingMessage.is_hidden {
                        warningBanner
                    }
                    
                    // MARK: - Body
                    if !displayingMessage.body.isEmpty {
                        bodySection
                    }
                    
                    // MARK: - Voice
                    if let voiceUrl = displayingMessage.voice_url, let url = URL(string: voiceUrl) {
                        voiceSection(url: url)
                    }
                    
                    // MARK: - Info Message
                    if let infoMessage {
                        Text(infoMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    // MARK: - Owner Bottom Actions
                    if isOwner {
                        ownerBottomActions
                    }
                    
                    // Spacer for visitor (steal button at bottom)
                    if !isOwner {
                        Spacer(minLength: 100)
                    } else {
                        Spacer(minLength: 50)
                    }
                }
            }
            
            // MARK: - Steal Button Fixed at Bottom (Visitor Only)
            if !isOwner {
                VStack {
                    Spacer()
                    stealButtonFixed
                }
            }
            
            // MARK: - Tooltip Overlay
            if !isOwner {
                tooltipOverlay
            }
        }
        .background(isOwner ? Color(red: 255/255, green: 252/255, blue: 240/255) : Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isOwner {
                    ownerMenu
                } else {
                    visitorMenu
                }
            }
        }
        .onDisappear { audioPlayer?.pause() }
        .alert("コピーしました", isPresented: $showingCopyAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                Task { await deleteMessage() }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("この操作は取り消せません")
        }
        .sheet(isPresented: $isPresentingEditSheet) {
            NavigationStack {
                NewMessageView(
                    service: service,
                    editingMessage: displayingMessage,
                    onCompleted: { updatedMessage in
                        self.displayingMessage = updatedMessage
                        self.audioPlayer?.replaceCurrentItem(with: nil)
                        self.isPlaying = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showingUnlockView) {
            UnlockView(
                service: service,
                targetMessage: displayingMessage,
                rootKeyword: .constant("")
            )
        }
    }
    
    // MARK: - Owner Menu
    private var ownerMenu: some View {
        Menu {
            Button {
                isPresentingEditSheet = true
            } label: {
                Label("編集", systemImage: "pencil")
            }
            
            Button {
                UIPasteboard.general.string = displayingMessage.keyword
                showingCopyAlert = true
            } label: {
                Label("合言葉をコピー", systemImage: "doc.on.doc")
            }
            
            if allowDelete {
                Divider()
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Visitor Menu
    private var visitorMenu: some View {
        Menu {
            Button {
                showingUnlockView = true
            } label: {
                Label("この投稿を奪う", systemImage: "lock.open")
            }
            
            Button(role: .destructive) {
                Task { await report() }
            } label: {
                Label("報告", systemImage: "flag")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Owner Header Section (With Crown)
    private var ownerHeaderSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(goldGradient)
                    .offset(y: -35)
                
                ZStack {
                    Circle()
                        .stroke(goldGradient, lineWidth: 3)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 20)
            
            HStack(spacing: 8) {
                Text(displayingMessage.keyword)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Button {
                    UIPasteboard.general.string = displayingMessage.keyword
                    showingCopyAlert = true
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                Text("あなたの投稿")
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(goldGradient)
            .cornerRadius(16)
            
            Text(formatDate(displayingMessage.createdAt))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }
    
    // MARK: - Stats Dashboard (Owner Only)
    private var statsDashboard: some View {
        VStack(spacing: 16) {
            Text("📊 統計")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                statCard(icon: "eye.fill", value: displayingMessage.view_count, label: "閲覧", color: .blue)
                statCard(icon: "lock.open.fill", value: displayingMessage.stolen_count, label: "奪取された", color: .purple)
                statCard(icon: "shield.fill", value: displayingMessage.failed_count, label: "防衛成功", color: .green)
            }
            
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(displayingMessage.is_4_digit ? .green : .orange)
                
                Text(displayingMessage.is_4_digit ? "4桁モード（高セキュリティ）" : "3桁モード")
                    .font(.subheadline)
                
                Spacer()
                
                if !displayingMessage.is_4_digit {
                    Text("4桁にアップグレード可能")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
        }
        .padding(16)
        .background(subtleGray)
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func statCard(icon: String, value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Visitor Header Section
    private var visitorHeaderSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(instagramGradient, lineWidth: 2)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 38, height: 38)
                
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(displayingMessage.keyword)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatDate(displayingMessage.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                Text(displayingMessage.is_4_digit ? "4桁" : "3桁")
            }
            .font(.caption)
            .foregroundColor(displayingMessage.is_4_digit ? .green : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill((displayingMessage.is_4_digit ? Color.green : Color.orange).opacity(0.1))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Visitor Stats Bar with Tooltips
    private var visitorStatsBar: some View {
        HStack(spacing: 20) {
            // Views
            statIconWithTooltip(
                systemName: "eye.fill",
                value: displayingMessage.view_count,
                color: .secondary,
                isShowingTooltip: $showViewTooltip,
                tooltipText: "閲覧数"
            )
            
            // Challenge attempts (spear)
            statIconWithTooltip(
                systemName: "arrowtriangle.up.fill",
                value: displayingMessage.failed_count,
                color: .orange,
                isShowingTooltip: $showChallengeTooltip,
                tooltipText: "挑戦した人の数"
            )
            
            // Defense (shield)
            statIconWithTooltip(
                systemName: "shield.fill",
                value: displayingMessage.failed_count,
                color: .green,
                isShowingTooltip: $showDefenseTooltip,
                tooltipText: "防衛成功回数"
            )
            
            // Stolen count (lock open)
            statIconWithTooltip(
                systemName: "lock.open.fill",
                value: displayingMessage.stolen_count,
                color: .purple,
                isShowingTooltip: $showStolenTooltip,
                tooltipText: "奪取された回数"
            )
            
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func statIconWithTooltip(
        systemName: String,
        value: Int,
        color: Color,
        isShowingTooltip: Binding<Bool>,
        tooltipText: String
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
            Text("\(value)")
        }
        .foregroundColor(color)
        .onLongPressGesture(minimumDuration: 0.3) {
            hideAllTooltips()
            isShowingTooltip.wrappedValue = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isShowingTooltip.wrappedValue = false
            }
        }
    }
    
    private func hideAllTooltips() {
        showViewTooltip = false
        showChallengeTooltip = false
        showDefenseTooltip = false
        showStolenTooltip = false
    }
    
    // MARK: - Tooltip Overlay
    private var tooltipOverlay: some View {
        VStack {
            if showViewTooltip {
                tooltipBubble(text: "閲覧数")
            } else if showChallengeTooltip {
                tooltipBubble(text: "挑戦した人の数")
            } else if showDefenseTooltip {
                tooltipBubble(text: "防衛成功回数")
            } else if showStolenTooltip {
                tooltipBubble(text: "奪取された回数")
            }
            Spacer()
        }
        .padding(.top, 120)
        .animation(.easeInOut(duration: 0.2), value: showViewTooltip)
        .animation(.easeInOut(duration: 0.2), value: showChallengeTooltip)
        .animation(.easeInOut(duration: 0.2), value: showDefenseTooltip)
        .animation(.easeInOut(duration: 0.2), value: showStolenTooltip)
    }
    
    private func tooltipBubble(text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Image Carousel
    private func imageCarousel(urls: [String]) -> some View {
        TabView(selection: $currentImageIndex) {
            ForEach(urls.indices, id: \.self) { index in
                AsyncImage(url: URL(string: urls[index])) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .overlay(ProgressView())
                }
                .frame(maxWidth: .infinity)
                .frame(height: 350)
                .clipped()
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
        .frame(height: 350)
        .cornerRadius(isOwner ? 20 : 0)
        .padding(.horizontal, isOwner ? 16 : 0)
    }
    
    // MARK: - Warning Banner
    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("⚠️ 非公開状態")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("24時間以内に編集して再公開しないと削除されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Body Section
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isOwner {
                Text("メッセージ")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(displayingMessage.body)
                .font(.subheadline)
                .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Voice Section
    private func voiceSection(url: URL) -> some View {
        Button {
            toggleAudio(url: url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isOwner ? goldGradient : instagramGradient)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ボイスメッセージ")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(isPlaying ? "再生中..." : "タップして再生")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 3, height: CGFloat.random(in: 10...25))
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Owner Bottom Actions
    private var ownerBottomActions: some View {
        VStack(spacing: 12) {
            Button {
                isPresentingEditSheet = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("編集する")
                }
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(goldGradient)
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = displayingMessage.keyword
                    showingCopyAlert = true
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("合言葉をコピー")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                
                if allowDelete {
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("削除")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
    
    // MARK: - Steal Button Fixed at Bottom
    private var stealButtonFixed: some View {
        Button {
            showingUnlockView = true
        } label: {
            HStack {
                Image(systemName: "lock.open.fill")
                    .font(.headline)
                
                Text("この投稿を奪う")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(instagramGradient)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [.white.opacity(0), .white, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .allowsHitTesting(false)
        , alignment: .bottom)
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func toggleAudio(url: URL) {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            let item = AVPlayerItem(url: url)
            if audioPlayer == nil {
                audioPlayer = AVPlayer(playerItem: item)
            } else {
                audioPlayer?.replaceCurrentItem(with: item)
            }
            
            if audioPlayer?.currentItem?.currentTime() == audioPlayer?.currentItem?.duration {
                audioPlayer?.seek(to: .zero)
            }
            
            audioPlayer?.play()
            isPlaying = true
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: audioPlayer?.currentItem,
                queue: .main
            ) { _ in
                self.isPlaying = false
                self.audioPlayer?.seek(to: .zero)
            }
        }
    }
    
    private func report() async {
        guard !isReporting else { return }
        isReporting = true
        defer { isReporting = false }
        
        try? await service.reportMessage(displayingMessage)
        await MainActor.run {
            infoMessage = "報告しました"
        }
    }
    
    private func deleteMessage() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        
        try? await service.deleteMessage(displayingMessage)
        await MainActor.run {
            dismiss()
        }
    }
}
