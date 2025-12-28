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
    
    private let subtleGray = Color(red: 250/255, green: 250/255, blue: 250/255)

    init(message: Message, service: MessageService, allowDelete: Bool) {
        _displayingMessage = State(initialValue: message)
        self.service = service
        self.allowDelete = allowDelete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Header
                headerSection
                
                // MARK: - Image Carousel
                if let urls = displayingMessage.image_urls, !urls.isEmpty {
                    imageCarousel(urls: urls)
                }
                
                // MARK: - Action Bar
                actionBar
                
                // MARK: - Stats
                statsSection
                
                // MARK: - Hidden Warning (Owner Only)
                if service.isOwner(of: displayingMessage) && displayingMessage.is_hidden {
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
                
                // MARK: - Bottom Actions
                bottomActions
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if service.isOwner(of: displayingMessage) {
                        Button {
                            isPresentingEditSheet = true
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        
                        if allowDelete {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    } else {
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
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.primary)
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .stroke(
                        service.isOwner(of: displayingMessage)
                        ? instagramGradient
                        : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
                    .frame(width: 44, height: 44)
                
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 38, height: 38)
                
                Image(systemName: service.isOwner(of: displayingMessage) ? "person.fill.checkmark" : "person.fill")
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayingMessage.keyword)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    // Copy button
                    Button {
                        UIPasteboard.general.string = displayingMessage.keyword
                        showingCopyAlert = true
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(formatDate(displayingMessage.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Owner badge
            if service.isOwner(of: displayingMessage) {
                Text("あなたの投稿")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(instagramGradient)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
                .frame(height: 400)
                .clipped()
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .automatic : .never))
        .frame(height: 400)
    }
    
    // MARK: - Action Bar
    private var actionBar: some View {
        HStack(spacing: 20) {
            // Stats
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                Text("\(displayingMessage.view_count)")
            }
            .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                Text("\(displayingMessage.stolen_count)")
            }
            .foregroundColor(.green)
            
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                Text("\(displayingMessage.failed_count)")
            }
            .foregroundColor(.red)
            
            Spacer()
            
            // Lock status
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                Text(displayingMessage.is_4_digit ? "4桁" : "3桁")
            }
            .font(.caption)
            .foregroundColor(displayingMessage.is_4_digit ? .green : .orange)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack {
            Text("\(displayingMessage.view_count)回閲覧")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Warning Banner
    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("非公開状態")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("24時間以内に編集して再公開しないと削除されます")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Body Section
    private var bodySection: some View {
        HStack {
            Text(displayingMessage.body)
                .font(.subheadline)
                .lineLimit(nil)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Voice Section
    private func voiceSection(url: URL) -> some View {
        Button {
            toggleAudio(url: url)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(instagramGradient)
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
                
                // Waveform placeholder
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 3, height: CGFloat.random(in: 10...25))
                    }
                }
            }
            .padding(12)
            .background(subtleGray)
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 12) {
            if !service.isOwner(of: displayingMessage) {
                // Steal button for non-owners
                Button {
                    showingUnlockView = true
                } label: {
                    HStack {
                        Image(systemName: "lock.open.fill")
                        Text("この投稿を奪う")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(instagramGradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
            } else {
                // Edit button for owners
                Button {
                    isPresentingEditSheet = true
                } label: {
                    HStack {
                        Image(systemName: "pencil")
                        Text("編集する")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 16)
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
