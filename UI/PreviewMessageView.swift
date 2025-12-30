import SwiftUI
import AVFoundation

struct PreviewMessageView: View {
    let message: Message
    let service: MessageService
    
    @Binding var rootKeyword: String
    @Binding var isPresented: Bool
    
    @EnvironmentObject var sessionStore: SessionStore
    
    @State private var showingUnlockView = false
    @State private var showingAuthPrompt = false
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false
    
    @State private var isReporting = false
    @State private var reportAlertMessage: String?
    @State private var showingReportAlert = false

    var body: some View {
        ZStack {
            // MARK: - Background
            AppColors.background.ignoresSafeArea()
            
            // 背景の装飾
            GeometryReader { proxy in
                Circle()
                    .fill(AppColors.primaryLight.opacity(0.3))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -50, y: -100)
                
                Circle()
                    .fill(AppColors.accent.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .position(x: proxy.size.width, y: proxy.size.height * 0.8)
            }
            
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: AppColors.primary.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
                .padding()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // MARK: - Main Card
                        VStack(spacing: 20) {
                            // Keyword Title
                            VStack(spacing: 8) {
                                Text(message.keyword)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(formatDate(message.createdAt))
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(AppColors.background)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 10)

                            // Stats
                            HStack(spacing: 16) {
                                statBadge(icon: "eye.fill", count: message.view_count, color: AppColors.accent)
                                statBadge(icon: "flag.fill", count: message.stolen_count, color: AppColors.success)
                                statBadge(icon: "burst.fill", count: message.failed_count, color: AppColors.error)
                            }

                            Divider()
                                .padding(.horizontal)

                            // MARK: - Content
                            VStack(alignment: .leading, spacing: 20) {
                                // Images
                                if let urls = message.image_urls, !urls.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(urls, id: \.self) { urlString in
                                                if let url = URL(string: urlString) {
                                                    AsyncImage(url: url) { image in
                                                        image.resizable().scaledToFill()
                                                    } placeholder: {
                                                        ZStack {
                                                            AppColors.background
                                                            ProgressView()
                                                                .tint(AppColors.primary)
                                                        }
                                                    }
                                                    .frame(width: 200, height: 140)
                                                    .clipped()
                                                    .cornerRadius(16)
                                                    .shadow(color: AppColors.primary.opacity(0.1), radius: 4, x: 0, y: 2)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.bottom, 8)
                                    }
                                }

                                // Body Text
                                if !message.body.isEmpty {
                                    Text(message.body)
                                        .font(.body)
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineSpacing(4)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(AppColors.background.opacity(0.5))
                                        .cornerRadius(16)
                                }

                                // Voice
                                if let voiceUrl = message.voice_url, let url = URL(string: voiceUrl) {
                                    Button {
                                        toggleAudio(url: url)
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(AppColors.primary)
                                                    .frame(width: 44, height: 44)
                                                
                                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                                    .foregroundColor(.white)
                                                    .font(.title3)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("ボイスメッセージ")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(AppColors.textPrimary)
                                                Text(isPlaying ? "再生中..." : "タップして再生")
                                                    .font(.caption)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            Spacer()
                                            
                                            Image(systemName: "waveform")
                                                .foregroundColor(AppColors.primary.opacity(0.5))
                                                .font(.title2)
                                        }
                                        .padding(10)
                                        .background(Color.white)
                                        .cornerRadius(30)
                                        .shadow(color: AppColors.primary.opacity(0.08), radius: 5, x: 0, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 30)
                                                .stroke(AppColors.primary.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: AppColors.primary.opacity(0.08), radius: 15, x: 0, y: 5)
                        .padding(.horizontal)

                        // MARK: - Steal Button
                        Button {
                            if sessionStore.isGuestMode {
                                showingAuthPrompt = true
                            } else {
                                showingUnlockView = true
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                
                                Text("この投稿を奪う")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text(securityLevelText)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.primaryGradient)
                            .cornerRadius(16)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal)
                        
                        // Report Link
                        Button {
                            Task { await report() }
                        } label: {
                            if isReporting {
                                ProgressView()
                                    .tint(AppColors.textSecondary)
                            } else {
                                Text("不適切な投稿として通報する")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .underline()
                            }
                        }
                        .padding(.bottom, 20)
                        
                        Spacer(minLength: 50)
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
        .sheet(isPresented: $showingAuthPrompt) {
            AuthPromptView(feature: "挑戦")
        }
        .alert("お知らせ", isPresented: $showingReportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(reportAlertMessage ?? "")
        }
    }
    
    // MARK: - Computed Properties
    
    private var securityLevelText: String {
        let length = message.passcode_length ?? (message.is_4_digit ? 4 : 3)
        return "🔒 \(length)桁の暗証番号"
    }
    
    // MARK: - Helpers
    
    private func statBadge(icon: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.bold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
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
                reportAlertMessage = "通報を受け付けました。"
                showingReportAlert = true
            }
        } catch {
            await MainActor.run {
                reportAlertMessage = "通報に失敗しました。"
                showingReportAlert = true
            }
        }
    }
}
