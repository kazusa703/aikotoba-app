import SwiftUI
import AVFoundation

struct PreviewMessageView: View {
    // データ受け取り用
    let message: Message
    let service: MessageService
    
    // RootViewの状態を操作するためのBinding
    @Binding var rootKeyword: String // 検索ワード（成功時に消すため）
    @Binding var isPresented: Bool   // この画面を閉じるため
    
    // 奪う画面の表示フラグ
    @State private var showingUnlockView = false
    
    // ボイス再生用
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false
    
    // 通報用の状態
    @State private var isReporting = false
    @State private var reportAlertMessage: String?
    @State private var showingReportAlert = false

    var body: some View {
        VStack(spacing: 24) {
            // ハンドルバー（シートの持ち手）
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            // 題名
            Text(message.keyword)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // 閲覧数・奪取数・防衛数
            HStack(spacing: 16) {
                Spacer()
                
                // 閲覧数
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                    Text("\(message.view_count)")
                }
                
                // 奪われた回数
                HStack(spacing: 4) {
                    Text("🏴")
                    Text("\(message.stolen_count)")
                }
                
                // 防衛した回数
                HStack(spacing: 4) {
                    Text("💣")
                    Text("\(message.failed_count)")
                }
            }
            .foregroundColor(.secondary)
            .font(.subheadline)
            
            Divider()
            
            // 内容（スクロール可能）
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 画像表示（横スクロール）
                    if let urls = message.image_urls, !urls.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(urls, id: \.self) { urlString in
                                    if let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Color.gray.opacity(0.3)
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            case .failure:
                                                Color.gray.opacity(0.3)
                                            @unknown default:
                                                Color.gray.opacity(0.3)
                                            }
                                        }
                                        .frame(width: 200, height: 150)
                                        .clipped()
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                    }
                    
                    // テキスト本文
                    Text(message.body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // ボイスメッセージ
                    if let voiceUrl = message.voice_url, let url = URL(string: voiceUrl) {
                        Button {
                            toggleAudio(url: url)
                        } label: {
                            HStack {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.blue)
                                
                                Text(isPlaying ? "再生中" : "ボイスを聞く")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 300)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            
            Divider()
            
            // 奪うボタン（鍵マーク）
            Button {
                showingUnlockView = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(message.is_4_digit ? .green : .orange)
                    
                    Text("この投稿を奪う")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(message.is_4_digit ? "4桁の暗証番号" : "3桁の暗証番号")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(uiColor: .systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(message.is_4_digit ? Color.green : Color.orange, lineWidth: 2)
                )
            }
            
            // 通報ボタン
            Button {
                Task { await report() }
            } label: {
                if isReporting {
                    ProgressView().font(.caption)
                } else {
                    Text("通報する")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .underline()
                }
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .padding()
        // 画面が閉じるときに音声を止める
        .onDisappear {
            audioPlayer?.pause()
        }
        // ★この画面の上から「奪う画面」を出す
        .fullScreenCover(isPresented: $showingUnlockView) {
            UnlockView(
                service: service,
                targetMessage: message,
                rootKeyword: $rootKeyword
            )
            .onDisappear {
                // 成功または諦めて×を押した（検索ワードが消えた）なら、このプレビューシートも閉じる
                if rootKeyword.isEmpty {
                    isPresented = false
                }
            }
        }
        // 通報完了アラート
        .alert("お知らせ", isPresented: $showingReportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(reportAlertMessage ?? "")
        }
    }
    
    // MARK: - Logic Methods
    
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
                reportAlertMessage = "通報を受け付けました。\nご協力ありがとうございます。"
                showingReportAlert = true
            }
        } catch {
            await MainActor.run {
                reportAlertMessage = "通報に失敗しました。\n時間をおいて再度お試しください。"
                showingReportAlert = true
            }
        }
    }
}
