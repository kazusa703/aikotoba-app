import SwiftUI
import AVFoundation
import PhotosUI

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss

    let editingMessage: Message?

    @State private var keyword: String
    @State private var bodyText: String
    @State private var passcode: String = ""
    @State private var is4DigitMode: Bool = false
    
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var recordedFileURL: URL?
    
    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingPreview = false
    
    @State private var isExistingVoiceDeleted = false
    
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var newSelectedImages: [UIImage] = []
    @State private var remainingImageUrls: [String] = []

    let service: MessageService
    let onCompleted: (Message) -> Void

    init(service: MessageService, editingMessage: Message? = nil, onCompleted: @escaping (Message) -> Void) {
        self.service = service
        self.editingMessage = editingMessage
        self.onCompleted = onCompleted
        
        _keyword = State(initialValue: editingMessage?.keyword ?? "")
        _bodyText = State(initialValue: editingMessage?.body ?? "")
        
        if let message = editingMessage, let urls = message.image_urls {
            _remainingImageUrls = State(initialValue: urls)
        }
        
        if let message = editingMessage {
            _is4DigitMode = State(initialValue: message.is_4_digit)
            _passcode = State(initialValue: message.passcode == "000" ? "" : message.passcode)
        }
    }
    
    var isEditing: Bool { editingMessage != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // --- 合言葉 ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("合言葉")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if isEditing {
                            Text("（変更不可）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    TextField("世界で一つだけ", text: $keyword)
                        .padding()
                        .background(isEditing ? Color.gray.opacity(0.2) : Color(uiColor: .systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary, lineWidth: 2)
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(isEditing)
                }

                // --- 内容 ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.headline)
                        .foregroundColor(.primary)

                    ZStack(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("内容を入力")
                                .foregroundColor(.secondary.opacity(0.5))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 150)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary, lineWidth: 2)
                            )
                    }
                }
                
                // --- パスコード設定 ---
                VStack(alignment: .leading, spacing: 12) {
                    Text("暗証番号設定（奪い合い機能）")
                        .font(.headline)
                    
                    if !is4DigitMode {
                        HStack {
                            Text("3桁（000〜999）")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                is4DigitMode = true
                            } label: {
                                Text("4桁に強化 (¥500)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                            }
                        }
                        TextField("例: 123", text: $passcode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: passcode) { _, val in
                                if val.count > 3 { passcode = String(val.prefix(3)) }
                            }
                        Text("※ 当てられやすく、奪われる可能性があります")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else {
                        HStack {
                            Text("🔒 4桁（0000〜9999）")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Spacer()
                            Button("3桁に戻す") {
                                is4DigitMode = false
                                passcode = ""
                            }
                            .font(.caption)
                        }
                        TextField("例: 1234", text: $passcode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: passcode) { _, val in
                                if val.count > 4 { passcode = String(val.prefix(4)) }
                            }
                        Text("※ セキュリティが強化されました")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
                
                // --- 画像セクション ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("画像（最大5枚）")
                            .font(.headline)
                        Spacer()
                        let totalCount = remainingImageUrls.count + newSelectedImages.count
                        if totalCount > 0 {
                            Text("\(totalCount) / 5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !remainingImageUrls.isEmpty || !newSelectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(remainingImageUrls, id: \.self) { urlString in
                                    ZStack(alignment: .topTrailing) {
                                        if let url = URL(string: urlString) {
                                            AsyncImage(url: url) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Color.gray.opacity(0.3)
                                            }
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                        }
                                        
                                        Button {
                                            removeExistingImage(url: urlString)
                                        } label: {
                                            XMarkButton()
                                        }
                                        .padding(4)
                                    }
                                }
                                
                                ForEach(newSelectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: newSelectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                        
                                        Button {
                                            removeNewImage(at: index)
                                        } label: {
                                            XMarkButton()
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    
                    let totalCount = remainingImageUrls.count + newSelectedImages.count
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 5 - totalCount,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text((remainingImageUrls.isEmpty && newSelectedImages.isEmpty) ? "画像を選択" : "画像を追加する")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .disabled(totalCount >= 5)
                    .opacity(totalCount >= 5 ? 0.6 : 1.0)
                }
                .onChange(of: selectedPhotoItems) { oldItems, newItems in
                    loadNewImages(from: newItems)
                }
                
                // --- ボイスメッセージ ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("ボイスメッセージ（任意）")
                        .font(.headline)
                    
                    if let _ = recordedFileURL {
                        voicePlaybackView(title: "新規録音済み", onDelete: deleteRecording)
                        
                    } else if isEditing && editingMessage?.voice_url != nil && !isExistingVoiceDeleted {
                        if let urlString = editingMessage?.voice_url, let url = URL(string: urlString) {
                            voicePlaybackView(title: "既存のボイスあり", onDelete: {
                                isExistingVoiceDeleted = true
                            }, playUrl: url)
                        }
                        
                    } else {
                        recordButtonView
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(isEditing ? "メッセージを編集" : "新しいメッセージ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await submit() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isEditing ? "更新" : "投稿")
                            .fontWeight(.bold)
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .onAppear {
            requestMicrophonePermission()
        }
        .onDisappear {
            audioPlayer?.pause()
        }
    }
    
    // MARK: - UI Components
    
    private func XMarkButton() -> some View {
        Image(systemName: "xmark.circle.fill")
            .foregroundColor(.white)
            .background(Color.black.opacity(0.5).clipShape(Circle()))
    }
    
    private func voicePlaybackView(title: String, onDelete: @escaping () -> Void, playUrl: URL? = nil) -> some View {
        HStack {
            Button {
                if isPlayingPreview {
                    stopPlayback()
                } else {
                    if let url = playUrl ?? recordedFileURL {
                        startPlayback(url: url)
                    }
                }
            } label: {
                Image(systemName: isPlayingPreview ? "stop.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.blue)
            }
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    private var recordButtonView: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(isRecording ? .red : .blue)
                if isRecording {
                    Text("録音中...")
                        .foregroundColor(.red)
                        .transition(.opacity)
                } else {
                    Text("録音する")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - Logic Methods
    
    private func removeExistingImage(url: String) {
        remainingImageUrls.removeAll { $0 == url }
    }
    
    private func removeNewImage(at index: Int) {
        newSelectedImages.remove(at: index)
        if index < selectedPhotoItems.count {
            selectedPhotoItems.remove(at: index)
        }
    }
    
    private func loadNewImages(from items: [PhotosPickerItem]) {
        Task {
            var loadedImages: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    loadedImages.append(image)
                }
            }
            await MainActor.run {
                newSelectedImages = loadedImages
            }
        }
    }

    private var canSubmit: Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !passcode.isEmpty
    }
    
    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        var newVoiceData: Data? = nil
        if let url = recordedFileURL, let data = try? Data(contentsOf: url) {
            newVoiceData = data
        }
        
        var newImagesData: [Data] = []
        for image in newSelectedImages {
            if let data = image.jpegData(compressionQuality: 0.8) {
                newImagesData.append(data)
            }
        }

        do {
            let resultMessage: Message
            
            if let editingMessage = editingMessage {
                resultMessage = try await service.updateMessage(
                    message: editingMessage,
                    keyword: trimmedKeyword,
                    body: trimmedBody,
                    shouldDeleteVoice: isExistingVoiceDeleted,
                    newVoiceData: newVoiceData,
                    remainingImageUrls: remainingImageUrls,
                    newImagesData: newImagesData,
                    passcode: passcode,
                    is4Digit: is4DigitMode
                )
            } else {
                resultMessage = try await service.createMessage(
                    keyword: trimmedKeyword,
                    body: trimmedBody,
                    voiceData: newVoiceData,
                    imagesData: newImagesData,
                    passcode: passcode,
                    is4Digit: is4DigitMode
                )
            }
            
            await MainActor.run {
                onCompleted(resultMessage)
                dismiss()
            }
        } catch MessageServiceError.keywordAlreadyExists {
            await MainActor.run {
                errorMessage = "この合言葉はすでに使われています。別の合言葉を試してください。"
                            }
                        } catch {
                            // ★修正: エラー内容を目立つようにコンソールに出力
                            print("==========================================")
                            print("投稿エラー詳細: \(error)")
                            print("==========================================")

                            await MainActor.run {
                                errorMessage = "処理に失敗しました。時間をおいて再度お試しください。"
                            }
                        }
                    }
    
    // MARK: - Audio Logic
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
    
    private func startRecording() {
        if isEditing && editingMessage?.voice_url != nil {
            isExistingVoiceDeleted = true
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = docPath.appendingPathComponent("temp_recording.m4a")
            let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            withAnimation { isRecording = true }
        } catch { print("録音開始エラー: \(error)") }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        withAnimation { isRecording = false; recordedFileURL = audioRecorder?.url }
    }
    
    private func deleteRecording() {
        recordedFileURL = nil
        audioRecorder = nil
    }
    
    private func startPlayback(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        if audioPlayer == nil {
            audioPlayer = AVPlayer(playerItem: playerItem)
        } else {
            audioPlayer?.replaceCurrentItem(with: playerItem)
        }
        audioPlayer?.play()
        isPlayingPreview = true
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: audioPlayer?.currentItem, queue: .main) { _ in
            self.isPlayingPreview = false
            self.audioPlayer?.seek(to: .zero)
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.pause()
        isPlayingPreview = false
    }
}
