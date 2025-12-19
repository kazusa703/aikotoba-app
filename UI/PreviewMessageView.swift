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

    var body: some View {
        ZStack {
            // MARK: - 1. 背景デザイン (RootViewと統一)
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            // 背景の装飾（ふんわりした円）
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
                    // 閉じるボタン
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
                                
                                // 登録日
                                Text(formatDate(message.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .padding(.top, 10)

                            // 統計データ（アイコン付きバッジ）
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
                                        .padding(.horizontal, 4) // 影が見えるように余白
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

                        // MARK: - アクションボタン (奪う)
                        // PreviewMessageView.swift の 奪うボタン（Button）部分を修正

                                    // 奪うボタン
                                    Button {
                                        showingUnlockView = true
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(message.is_4_digit ? .white : .orange) // 4桁なら白文字
                                            
                                            Text("この投稿を奪う")
                                                .font(.headline)
                                                .fontWeight(.bold)
                                                .foregroundColor(message.is_4_digit ? .white : .black)
                                            
                                            Text(message.is_4_digit ? "🔒 4桁（高難易度）" : "3桁の暗証番号")
                                                .font(.caption)
                                                .foregroundColor(message.is_4_digit ? .white.opacity(0.8) : .gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        // ★変更: 4桁の場合は豪華な背景（ゴールドグラデーション）にする
                                        .background(
                                            Group {
                                                if message.is_4_digit {
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color.orange, Color.yellow]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                } else {
                                                    Color.clear // 3桁は背景なし（枠線のみ）
                                                }
                                            }
                                        )
                                        // 3桁の場合の枠線
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(message.is_4_digit ? Color.clear : Color.orange, lineWidth: 3)
                                        )
                                        .cornerRadius(16)
                                        // 4桁の場合は影をつけて浮かび上がらせる
                                        .shadow(color: message.is_4_digit ? .orange.opacity(0.5) : .clear, radius: 10, x: 0, y: 5)
                                    }
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
        .alert("お知らせ", isPresented: $showingReportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(reportAlertMessage ?? "")
        }
    }
    
    // MARK: - Helpers
    
    // 統計バッジのデザイン用ヘルパー
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
