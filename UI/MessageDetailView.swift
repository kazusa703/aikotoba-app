import SwiftUI
import AVFoundation

struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let message: Message
    let service: MessageService
    let allowDelete: Bool

    @State private var isReporting = false
    @State private var isDeleting = false
    @State private var infoMessage: String?
    @State private var showingDeleteAlert = false
    
    @State private var audioPlayer: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // --- 複数画像表示 ---
                    if let urls = message.image_urls, !urls.isEmpty {
                        // 横スクロールで見せる
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(urls, id: \.self) { urlString in
                                    if let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Rectangle()
                                                    .fill(Color.secondary.opacity(0.2))
                                                    .frame(width: 300, height: 250)
                                                    .overlay(ProgressView())
                                                    .cornerRadius(12)
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 300, height: 250)
                                                    .clipped()
                                                    .cornerRadius(12)
                                            case .failure:
                                                Rectangle()
                                                    .fill(Color.secondary.opacity(0.2))
                                                    .frame(width: 300, height: 250)
                                                    .overlay(Image(systemName: "photo.fill").foregroundColor(.secondary))
                                                    .cornerRadius(12)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // --- テキスト ---
                    Text(message.body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // --- ボイス ---
                    if let voiceUrl = message.voice_url, let url = URL(string: voiceUrl) {
                        HStack {
                            Button {
                                toggleAudio(url: url)
                            } label: {
                                HStack {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .resizable()
                                        .frame(width: 44, height: 44)
                                        .foregroundColor(.blue)
                                    Text(isPlaying ? "再生中" : "ボイスメッセージを聞く")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
            }

            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // --- ボタン類 ---
            HStack {
                if !service.isOwner(of: message) {
                    Button(role: .destructive) {
                        Task { await report() }
                    } label: {
                        if isReporting {
                            ProgressView()
                        } else {
                            Text("通報")
                        }
                    }
                }
                Spacer()
                if allowDelete && service.isOwner(of: message) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("削除")
                        }
                    }
                    .alert("本当に削除しますか？", isPresented: $showingDeleteAlert) {
                        Button("キャンセル", role: .cancel) { }
                        Button("削除", role: .destructive) {
                            Task { await deleteMessage() }
                        }
                    } message: {
                        Text("この操作は取り消せません。")
                    }
                }
            }
        }
        .padding()
        .navigationTitle(message.keyword)
        .onDisappear {
            audioPlayer?.pause()
        }
    }
    
    // (以下のメソッドは変更なし)
    private func report() async {
        guard !isReporting else { return }
        isReporting = true
        defer { isReporting = false }
        do { try await service.reportMessage(message); await MainActor.run { infoMessage = "通報を受け付けました。" } }
        catch { await MainActor.run { infoMessage = "通報失敗" } }
    }
    private func deleteMessage() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }
        do { try await service.deleteMessage(message); await MainActor.run { dismiss() } }
        catch { await MainActor.run { infoMessage = "削除失敗" } }
    }
    private func toggleAudio(url: URL) {
        if isPlaying { audioPlayer?.pause(); isPlaying = false } else {
            if audioPlayer == nil { audioPlayer = AVPlayer(playerItem: AVPlayerItem(url: url)) }
            if let item = audioPlayer?.currentItem, item.currentTime() == item.duration { audioPlayer?.seek(to: .zero) }
            audioPlayer?.play(); isPlaying = true
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: audioPlayer?.currentItem, queue: .main) { _ in self.isPlaying = false }
        }
    }
}
