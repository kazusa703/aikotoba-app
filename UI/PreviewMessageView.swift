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

    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                ScrollView {
                    VStack(spacing: 0) {
                        // MARK: - Header (User Info Style)
                        headerSection
                        
                        // MARK: - Image Carousel
                        if let urls = message.image_urls, !urls.isEmpty {
                            imageCarousel(urls: urls)
                        }
                        
                        // MARK: - Stats Bar with Tooltips
                        statsBar
                        
                        // MARK: - Body Text
                        if !message.body.isEmpty {
                            bodySection
                        }
                        
                        // MARK: - Voice Message
                        if let voiceUrl = message.voice_url, let url = URL(string: voiceUrl) {
                            voiceSection(url: url)
                        }
                        
                        // MARK: - Report
                        reportButton
                        
                        // Spacer to push steal button to bottom
                        Spacer(minLength: 100)
                    }
                }
                
                // MARK: - Steal Button (Fixed at bottom)
                VStack {
                    Spacer()
                    stealButton
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
                
                // MARK: - Tooltip Overlays
                tooltipOverlay
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
    
    // MARK: - Stats Bar with Long Press Tooltips
    private var statsBar: some View {
        HStack(spacing: 20) {
            // Views (eye icon)
            statIcon(
                systemName: "eye.fill",
                value: message.view_count,
                color: .secondary,
                isShowingTooltip: $showViewTooltip,
                tooltipText: "閲覧数"
            )
            
            // Challenge attempts (spear/arrow icon)
            statIcon(
                systemName: "arrowtriangle.up.fill",
                value: message.failed_count,
                color: .orange,
                isShowingTooltip: $showChallengeTooltip,
                tooltipText: "挑戦した人の数"
            )
            
            // Defense (shield icon)
            statIcon(
                systemName: "shield.fill",
                value: message.failed_count,
                color: .green,
                isShowingTooltip: $showDefenseTooltip,
                tooltipText: "防衛成功回数"
            )
            
            // Stolen count (lock open icon)
            statIcon(
                systemName: "lock.open.fill",
                value: message.stolen_count,
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
    
    private func statIcon(
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
            // Hide all other tooltips
            hideAllTooltips()
            isShowingTooltip.wrappedValue = true
            
            // Auto-hide after 2 seconds
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
        .padding(.top, 180) // Position below stats bar
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
            .cornerRadius(16)
            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
        }
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
