import SwiftUI
import AVFoundation

struct PreviewMessageView: View {
    let message: Message
    let service: MessageService
    
    @Binding var rootKeyword: String
    @Binding var isPresented: Bool
    
    @State private var showingUnlockView = false
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false
    
    @State private var isReporting = false
    @State private var reportAlertMessage: String?
    @State private var showingReportAlert = false
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Header (User Info Style)
                    headerSection
                    
                    // MARK: - Image Carousel
                    if let urls = message.image_urls, !urls.isEmpty {
                        imageCarousel(urls: urls)
                    }
                    
                    // MARK: - Action Bar
                    actionBar
                    
                    // MARK: - Stats
                    statsSection
                    
                    // MARK: - Body Text
                    if !message.body.isEmpty {
                        bodySection
                    }
                    
                    // MARK: - Voice Message
                    if let voiceUrl = message.voice_url, let url = URL(string: voiceUrl) {
                        voiceSection(url: url)
                    }
                    
                    // MARK: - Steal Button
                    stealButton
                    
                    // MARK: - Report
                    reportButton
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .onDisappear { audioPlayer?.pause() }
        .fullScreenCover(isPresented: $showingUnlockView) {
            UnlockView(
                service: service,
                targetMessage: message,
                rootKeyword: $rootKeyword
            )
            .onDisappear {
                if rootKeyword.isEmpty { isPresented = false }
            }
        }
        .alert("お知らせ", isPresented: $showingReportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(reportAlertMessage ?? "")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Avatar with gradient border
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
                Text(message.keyword)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(formatDate(message.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Lock indicator
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text(message.is_4_digit ? "4桁" : "3桁")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(message.is_4_digit ? .green : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(message.is_4_digit ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            )
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
        HStack(spacing: 16) {
            // Stats icons
            HStack(spacing: 4) {
                Image(systemName: "eye")
                Text("\(message.view_count)")
            }
            .foregroundColor(.secondary)
            
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
            
            Spacer()
            
            // Bookmark (decorative)
            Image(systemName: "bookmark")
                .foregroundColor(.primary)
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        HStack {
            Text("\(message.view_count)回閲覧")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - Body Section
    private var bodySection: some View {
        HStack {
            Text(message.body)
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
                
                // Waveform animation placeholder
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 3, height: CGFloat.random(in: 10...25))
                    }
                }
            }
            .padding(12)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Steal Button
    private var stealButton: some View {
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
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Report Button
    private var reportButton: some View {
        Button {
            Task { await report() }
        } label: {
            if isReporting {
                ProgressView()
            } else {
                Text("不適切な投稿として報告")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
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
        
        do {
            try await service.reportMessage(message)
            await MainActor.run {
                reportAlertMessage = "報告を受け付けました。"
                showingReportAlert = true
            }
        } catch {
            await MainActor.run {
                reportAlertMessage = "報告に失敗しました。"
                showingReportAlert = true
            }
        }
    }
}
