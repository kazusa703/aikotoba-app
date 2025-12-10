import SwiftUI
import AVFoundation

struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
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
    
    // MARK: - Unlock / Steal State
    @State private var showingUnlockAlert = false
    @State private var unlockInput = ""
    @State private var unlockErrorMessage: String?

    // MARK: - Init
    init(message: Message, service: MessageService, allowDelete: Bool) {
        _displayingMessage = State(initialValue: message)
        self.service = service
        self.allowDelete = allowDelete
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 所有権チェックによる表示分岐
            if service.isOwner(of: displayingMessage) {
                // --- 自分のもの（編集・削除可能） ---
                contentView(isOwner: true)
            } else {
                // --- 他人のもの（閲覧のみ + 奪うボタン） ---
                contentView(isOwner: false)
            }
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if service.isOwner(of: displayingMessage) {
                    // 持ち主なら「編集」
                    Button("編集") {
                        isPresentingEditSheet = true
                    }
                } else {
                    // 他人の投稿なら「奪う（鍵アイコン）」
                    Button {
                        unlockInput = ""
                        unlockErrorMessage = nil
                        showingUnlockAlert = true
                    } label: {
                        VStack(spacing: 0) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(displayingMessage.is_4_digit ? .green : .orange)
                            Text("奪う")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .onDisappear {
                    audioPlayer?.pause()
                }
                // ★ .task ブロックを削除しました
                .alert("コピーしました",  isPresented: $showingCopyAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                Task { await deleteMessage() }
            }
            Button("キャンセル", role: .cancel) { }
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
        // ロック解除（奪取）用アラート
        .alert("暗証番号を入力", isPresented: $showingUnlockAlert) {
            TextField("番号", text: $unlockInput)
                .keyboardType(.numberPad)
            Button("キャンセル", role: .cancel) { }
            Button("解除に挑戦") {
                Task { await attemptUnlock() }
            }
        } message: {
            if let err = unlockErrorMessage {
                Text(err)
            } else {
                Text("正解すると投稿を奪えます。\n(1日1回のみ)")
            }
        }
    }
    
    // MARK: - Subviews
    
    // 共通のコンテンツ表示ビュー
    func contentView(isOwner: Bool) -> some View {
        VStack(spacing: 16) {
            
            // 閲覧数・奪取数・防衛数
                        HStack(spacing: 16) { // 少し間隔を広めに
                            Spacer()
                            
                            // 閲覧数
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                Text("\(displayingMessage.view_count)")
                            }
                            
                            // ★追加: 奪われた回数（フラッグ）
                            HStack(spacing: 4) {
                                Text("🏴") // SF Symbolsに良い旗がないため絵文字推奨
                                Text("\(displayingMessage.stolen_count)")
                            }
                            
                            // ★追加: 防衛した回数（爆弾）
                            HStack(spacing: 4) {
                                Text("💣")
                                Text("\(displayingMessage.failed_count)")
                            }
                        }
                        .foregroundColor(.secondary)
                        .font(.subheadline) // 少し文字サイズを統一
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // タイトル（合言葉）
                    HStack {
                        Text(displayingMessage.keyword)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Button {
                            UIPasteboard.general.string = displayingMessage.keyword
                            showingCopyAlert = true
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 非公開警告（自分の場合のみ表示）
                    if isOwner && displayingMessage.is_hidden {
                                            // ★ここを書き換え
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("⚠️ 非公開 / 削除警告")
                                                    .fontWeight(.bold)
                                                Text("現在、この投稿は非公開です。\n奪取から24時間以内に「編集」でパスコードを設定して再公開しない場合、この投稿は自動削除されます。")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(8)
                                        }

                    // 画像（横スクロール）
                    if let urls = displayingMessage.image_urls, !urls.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(urls, id: \.self) { urlString in
                                    AsyncImage(url: URL(string: urlString)) { phase in
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
                                    .frame(width: 300, height: 250)
                                    .clipped()
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    // 本文
                    Text(displayingMessage.body)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // ボイスメッセージ
                    if let voiceUrl = displayingMessage.voice_url, let url = URL(string: voiceUrl) {
                        Button {
                            toggleAudio(url: url)
                        } label: {
                            HStack {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.blue)
                                
                                Text(isPlaying ? "再生中" : "ボイスを再生")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
            }
            
            if let infoMessage {
                Text(infoMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()
            
            // ボタンエリア
            HStack {
                // 自分以外なら通報ボタン
                if !isOwner {
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
                
                // 自分のみ削除ボタン
                if allowDelete && isOwner {
                    Button("削除", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - Logic Methods
    
    private func attemptUnlock() async {
            unlockErrorMessage = nil
            
            do {
                // ★修正: message.id ではなく displayingMessage.id を使います
                let result = try await service.attemptSteal(messageId: displayingMessage.id, guess: unlockInput)
                
                if result == "success" {
                    // 成功したら画面を閉じる
                    await MainActor.run {
                        dismiss()
                    }
                } else if result == "limit_exceeded" {
                    unlockErrorMessage = "本日の挑戦回数は終了しました。"
                    showingUnlockAlert = true
                } else {
                    unlockErrorMessage = "番号が違います..."
                    showingUnlockAlert = true
                }
            } catch {
                unlockErrorMessage = "エラーが発生しました。"
                showingUnlockAlert = true
            }
        }
    
    private func report() async {
        guard !isReporting else { return }
        isReporting = true
        defer { isReporting = false }
        
        try? await service.reportMessage(displayingMessage)
        await MainActor.run {
            infoMessage = "通報しました"
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
}
