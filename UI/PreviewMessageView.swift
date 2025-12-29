import SwiftUI
import AVFoundation

struct PreviewMessageView: View {
    @EnvironmentObject var sessionStore: SessionStore
    
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
    
    // 認証促進シート
    @State private var showingAuthPrompt = false
    
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
        ZStack {
            // MARK: - 背景デザイン
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            GeometryReader { proxy in
                Circle()
                    .fill(
                        LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -50, y: -100)
                
                Circle()
                    .fill(
                        LinearGradient(colors: [.yellow.opacity(0.2), .orange.opacity(0.2)], startPoint: .bottomLeading, endPoint: .topTrailing)
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .position(x: proxy.size.width, y: proxy.size.height * 0.8)
            }
            
            VStack(spacing: 0) {
                // MARK: - ヘッダーエリア
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(10)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
                .padding()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // MARK: - メインカード
                        VStack(spacing: 20) {
                            
                            // 合言葉タイトル
                            VStack(spacing: 8) {
                                Text(message.keyword)
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                
                                Text(formatDate(message.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 10)

                            // 統計データ
                            HStack(spacing: 16) {
                                statBadge(icon: "eye.fill", count: message.view_count, color: .blue)
                                statBadge(icon: "flag.fill", count: message.stolen_count, color: .green)
                                statBadge(icon: "burst.fill", count: message.failed_count, color: .red)
                            }

                            Divider()
                                .padding(.horizontal)

                            // MARK: - コンテンツエリア
                            VStack(alignment: .leading, spacing: 20) {
                                // 画像
                                if let urls = message.image_urls, !urls.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(urls, id: \.self) { urlString in
                                                if let url = URL(string: urlString) {
                                                    AsyncImage(url: url) { image in
                                                        image.resizable().scaledToFill()
                                                    } placeholder: {
                                                        ZStack {
                                                            Color.gray.opacity(0.1)
                                                            ProgressView()
                                                        }
                                                    }
                                                    .frame(width: 200, height: 140)
                                                    .clipped()
                                                    .cornerRadius(16)
                                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.bottom, 8)
                                    }
                                }

                                // テキスト本文
                                if !message.body.isEmpty {
                                    Text(message.body)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                                        .cornerRadius(16)
                                }

                                // ボイス再生
                                if let voiceUrl = message.voice_url, let url = URL(string: voiceUrl) {
                                    Button {
                                        toggleAudio(url: url)
                                    } label: {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 44, height: 44)
                                                
                                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                                    .foregroundColor(.white)
                                                    .font(.title3)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("ボイスメッセージ")
                                                    .font(.subheadline)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.primary)
                                                Text(isPlaying ? "再生中..." : "タップして再生")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            
                                            Image(systemName: "waveform")
                                                .foregroundColor(.blue.opacity(0.5))
                                                .font(.title2)
                                        }
                                        .padding(10)
                                        .background(Color.white)
                                        .cornerRadius(30)
                                        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 30)
                                                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 10)

                        }
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 5)
                        .padding(.horizontal)

                        // MARK: - 奪うボタン
                        Button {
                            if sessionStore.isGuestMode {
                                showingAuthPrompt = true
                            } else {
                                showingUnlockView = true
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 28))
                                
                                Text("解除に挑戦")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Text(securityText)
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .foregroundColor(.white)
                            .background(instagramGradient)
                            .cornerRadius(16)
                            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.horizontal)
                        
                        // 通報リンク
                        Button {
                            Task { await report() }
                        } label: {
                            if isReporting {
                                ProgressView().font(.caption)
                            } else {
                                Text("不適切な投稿として通報する")
                                    .font(.caption)
                                    .foregroundColor(.gray)
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
    
    // MARK: - Helpers
    
    private var securityText: String {
        let length = message.passcode_length
        if length >= 8 { return "🛡️ \(length)桁 - 極めて強固" }
        if length >= 6 { return "🔒 \(length)桁 - 強固" }
        if length >= 4 { return "🔐 \(length)桁 - 標準" }
        return "⚠️ \(length)桁 - 推測されやすい"
    }
    
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
            if audioPlayer == nil { audioPlayer = AVPlayer(playerItem: item) } else { audioPlayer?.replaceCurrentItem(with: item) }
            if audioPlayer?.currentItem?.currentTime() == audioPlayer?.currentItem?.duration { audioPlayer?.seek(to: .zero) }
            audioPlayer?.play(); isPlaying = true
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: audioPlayer?.currentItem, queue: .main) { _ in self.isPlaying = false; self.audioPlayer?.seek(to: .zero) }
        }
    }
    
    private func report() async {
        guard !isReporting else { return }; isReporting = true; defer { isReporting = false }
        do {
            try await service.reportMessage(message)
            await MainActor.run { reportAlertMessage = "通報を受け付けました。"; showingReportAlert = true }
        } catch {
            await MainActor.run { reportAlertMessage = "通報に失敗しました。"; showingReportAlert = true }
        }
    }
}
