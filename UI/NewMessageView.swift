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
    
    var isPasscodeEditable: Bool {
        guard let msg = editingMessage else { return true }
        return msg.is_hidden
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Media Section
                    mediaSection
                    
                    // MARK: - Keyword Section
                    keywordSection
                    
                    // MARK: - Passcode Section
                    passcodeSection
                    
                    // MARK: - Body Section
                    bodySection
                    
                    // MARK: - Voice Section
                    voiceSection
                    
                    // Error Message
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
            .background(Color.white)
            .navigationTitle(isEditing ? "編集" : "新規投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(isEditing ? "更新" : "シェア")
                                .fontWeight(.bold)
                                .foregroundStyle(canSubmit ? instagramGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        }
                    }
                    .disabled(!canSubmit || isLoading)
                }
            }
            .onAppear { requestMicrophonePermission() }
            .onDisappear { audioPlayer?.pause() }
        }
    }
    
    // MARK: - Media Section
    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("写真")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if remainingImageUrls.count + newSelectedImages.count > 0 {
                    Text("\(remainingImageUrls.count + newSelectedImages.count)/5")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Image Preview
            if !remainingImageUrls.isEmpty || !newSelectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Existing images
                        ForEach(remainingImageUrls, id: \.self) { url in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: url)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color.gray.opacity(0.2)
                                }
                                .frame(width: 120, height: 120)
                                .clipped()
                                .cornerRadius(12)
                                
                                deleteButton { removeExistingImage(url: url) }
                            }
                        }
                        
                        // New images
                        ForEach(newSelectedImages.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: newSelectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipped()
                                    .cornerRadius(12)
                                
                                deleteButton { removeNewImage(at: index) }
                            }
                        }
                        
                        // Add button
                        if remainingImageUrls.count + newSelectedImages.count < 5 {
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 5 - (remainingImageUrls.count + newSelectedImages.count),
                                matching: .images
                            ) {
                                VStack(spacing: 8) {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                    Text("追加")
                                        .font(.caption)
                                }
                                .foregroundColor(.gray)
                                .frame(width: 120, height: 120)
                                .background(subtleGray)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Empty state - Photo picker
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("写真を追加")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(subtleGray)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
            }
        }
        .onChange(of: selectedPhotoItems) { _, new in
            loadNewImages(from: new)
        }
    }
    
    // MARK: - Keyword Section
    private var keywordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("合言葉")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("*必須")
                    .font(.caption)
                    .foregroundColor(.red)
                
                if isEditing {
                    Text("（変更不可）")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            TextField("世界でひとつだけの合言葉", text: $keyword)
                .padding(14)
                .background(subtleGray)
                .cornerRadius(12)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .disabled(isEditing)
                .opacity(isEditing ? 0.6 : 1)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Passcode Section
    private var passcodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("暗証番号")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("*必須")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                if isPasscodeEditable {
                    // Toggle Button
                    Button {
                        withAnimation {
                            is4DigitMode.toggle()
                            passcode = ""
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: is4DigitMode ? "lock.fill" : "lock.open.fill")
                            Text(is4DigitMode ? "4桁モード" : "3桁モード")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(is4DigitMode ? .green : .orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(is4DigitMode ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        )
                    }
                }
            }
            
            HStack(spacing: 12) {
                // Passcode Input
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.gray)
                    
                    TextField(is4DigitMode ? "0000〜9999" : "000〜999", text: $passcode)
                        .keyboardType(.numberPad)
                        .disabled(!isPasscodeEditable)
                }
                .padding(14)
                .background(subtleGray)
                .cornerRadius(12)
                .opacity(isPasscodeEditable ? 1 : 0.6)
                .onChange(of: passcode) { _, val in
                    let limit = is4DigitMode ? 4 : 3
                    if val.count > limit {
                        passcode = String(val.prefix(limit))
                    }
                }
            }
            
            // Security info
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text(is4DigitMode
                     ? "4桁は解読が難しく、投稿を守りやすくなります"
                     : "3桁は1000通り。他の人に奪われる可能性があります")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Body Section
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("メッセージ")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("メッセージを入力...")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $bodyText)
                    .frame(minHeight: 120)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(subtleGray)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Voice Section
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ボイスメッセージ")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if let _ = recordedFileURL {
                // Recorded voice preview
                voicePreviewCard(
                    title: "録音済み",
                    onPlay: { if let url = recordedFileURL { startPlayback(url: url) } },
                    onDelete: deleteRecording
                )
            } else if isEditing && editingMessage?.voice_url != nil && !isExistingVoiceDeleted {
                // Existing voice preview
                if let url = URL(string: editingMessage!.voice_url!) {
                    voicePreviewCard(
                        title: "既存のボイス",
                        onPlay: { startPlayback(url: url) },
                        onDelete: { isExistingVoiceDeleted = true }
                    )
                }
            } else {
                // Record button
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    isRecording
                                    ? AnyShapeStyle(Color.red)
                                    : AnyShapeStyle(instagramGradient)
                                )
                                .frame(width: 56, height: 56)
                            
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isRecording ? "録音中..." : "タップして録音")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("ボイスメッセージを追加")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(subtleGray)
                    .cornerRadius(16)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Views
    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundColor(.white)
                .background(Circle().fill(Color.black.opacity(0.6)))
        }
        .padding(6)
    }
    
    private func voicePreviewCard(title: String, onPlay: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                if isPlayingPreview {
                    stopPlayback()
                } else {
                    onPlay()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(instagramGradient)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: isPlayingPreview ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(isPlayingPreview ? "再生中..." : "タップで再生")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(12)
        .background(subtleGray)
        .cornerRadius(16)
    }

    // MARK: - Logic
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
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            await MainActor.run {
                newSelectedImages = images
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
    
    private func startRecording() {
        if isEditing && editingMessage?.voice_url != nil {
            isExistingVoiceDeleted = true
        }
        
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("temp.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        withAnimation { isRecording = true }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        withAnimation {
            isRecording = false
            recordedFileURL = audioRecorder?.url
        }
    }
    
    private func deleteRecording() {
        recordedFileURL = nil
    }
    
    private func startPlayback(url: URL) {
        let item = AVPlayerItem(url: url)
        if audioPlayer == nil {
            audioPlayer = AVPlayer(playerItem: item)
        } else {
            audioPlayer?.replaceCurrentItem(with: item)
        }
        audioPlayer?.play()
        isPlayingPreview = true
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: audioPlayer?.currentItem,
            queue: .main
        ) { _ in
            self.isPlayingPreview = false
            self.audioPlayer?.seek(to: .zero)
        }
    }
    
    private func stopPlayback() {
        audioPlayer?.pause()
        isPlayingPreview = false
    }

    private var canSubmit: Bool {
        let isKeywordValid = !keyword.trimmingCharacters(in: .whitespaces).isEmpty
        let isPasscodeValid = !passcode.isEmpty
        let hasBody = !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
        let hasVoice = recordedFileURL != nil || (isEditing && editingMessage?.voice_url != nil && !isExistingVoiceDeleted)
        let hasImage = !newSelectedImages.isEmpty || !remainingImageUrls.isEmpty
        return isKeywordValid && isPasscodeValid && (hasBody || hasVoice || hasImage)
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        
        let k = keyword.trimmingCharacters(in: .whitespaces)
        let b = bodyText.trimmingCharacters(in: .whitespaces)
        
        var voiceData: Data? = nil
        if let url = recordedFileURL, let data = try? Data(contentsOf: url) {
            voiceData = data
        }
        
        var imageData: [Data] = []
        for img in newSelectedImages {
            if let data = img.jpegData(compressionQuality: 0.8) {
                imageData.append(data)
            }
        }

        do {
            let result: Message
            if let editing = editingMessage {
                result = try await service.updateMessage(
                    message: editing,
                    keyword: k,
                    body: b,
                    shouldDeleteVoice: isExistingVoiceDeleted,
                    newVoiceData: voiceData,
                    remainingImageUrls: remainingImageUrls,
                    newImagesData: imageData,
                    passcode: passcode,
                    is4Digit: is4DigitMode
                )
            } else {
                result = try await service.createMessage(
                    keyword: k,
                    body: b,
                    voiceData: voiceData,
                    imagesData: imageData,
                    passcode: passcode,
                    is4Digit: is4DigitMode
                )
            }
            await MainActor.run {
                onCompleted(result)
                dismiss()
            }
        } catch MessageServiceError.keywordAlreadyExists {
            await MainActor.run {
                errorMessage = "この合言葉はすでに使用されています"
            }
        } catch {
            print("投稿エラー: \(error)")
            await MainActor.run {
                errorMessage = "投稿に失敗しました。時間をおいて再度お試しください。"
            }
        }
    }
}
