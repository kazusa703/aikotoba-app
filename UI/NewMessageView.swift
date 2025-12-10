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
            // 000(未設定)なら空欄、それ以外なら既存の番号を入れる
            _passcode = State(initialValue: message.passcode == "000" ? "" : message.passcode)
        }
    }
    
    var isEditing: Bool { editingMessage != nil }
    
    // ★追加: 暗証番号を変更できるかどうかの判定
    // 新規作成(nil) または 非公開(is_hidden=true) の時だけ変更可能
    // 公開中(is_hidden=false) の時は「一発勝負」なので変更不可
    var isPasscodeEditable: Bool {
        guard let msg = editingMessage else { return true }
        return msg.is_hidden
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. 合言葉（常に変更不可：編集モード時）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("合言葉（必須）").font(.headline)
                        if isEditing { Text("（変更不可）").font(.caption).foregroundColor(.secondary) }
                    }
                    TextField("世界で一つだけ", text: $keyword)
                        .padding()
                        .background(isEditing ? Color.gray.opacity(0.2) : Color(uiColor: .systemBackground))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary, lineWidth: 2))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .disabled(isEditing)
                }
                
                // 2. 暗証番号（必須・条件付き変更不可）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("暗証番号（必須）").font(.headline)
                        // ★変更不可ならラベルを表示
                        if !isPasscodeEditable {
                            Text("（変更不可）").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    if !is4DigitMode {
                        // --- 3桁モード ---
                        HStack {
                            Text("3桁（000〜999）").font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            // ★変更可能な時だけ切り替えボタンを表示
                            if isPasscodeEditable {
                                Button { is4DigitMode = true } label: {
                                    Text("4桁に強化 (¥500)").font(.caption).fontWeight(.bold)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.orange).foregroundColor(.white).cornerRadius(20)
                                }
                            }
                        }
                        TextField("例: 123", text: $passcode)
                            .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                            // ★変更不可ならグレーアウト＆入力無効化
                            .background(!isPasscodeEditable ? Color.gray.opacity(0.2) : Color(uiColor: .systemBackground))
                            .disabled(!isPasscodeEditable)
                            .onChange(of: passcode) { _, val in if val.count > 3 { passcode = String(val.prefix(3)) } }
                    } else {
                        // --- 4桁モード ---
                        HStack {
                            Text("🔒 4桁（0000〜9999）").font(.subheadline).fontWeight(.bold).foregroundColor(.green)
                            Spacer()
                            // ★変更可能な時だけ切り替えボタンを表示
                            if isPasscodeEditable {
                                Button("3桁に戻す") { is4DigitMode = false; passcode = "" }.font(.caption)
                            }
                        }
                        TextField("例: 1234", text: $passcode)
                            .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                            // ★変更不可ならグレーアウト＆入力無効化
                            .background(!isPasscodeEditable ? Color.gray.opacity(0.2) : Color(uiColor: .systemBackground))
                            .disabled(!isPasscodeEditable)
                            .onChange(of: passcode) { _, val in if val.count > 4 { passcode = String(val.prefix(4)) } }
                    }
                }
                .padding().background(Color(uiColor: .secondarySystemBackground)).cornerRadius(8)

                // 3. 内容（任意）
                VStack(alignment: .leading, spacing: 8) {
                    Text("内容").font(.headline)
                    ZStack(alignment: .topLeading) {
                        if bodyText.isEmpty { Text("内容を入力").foregroundColor(.secondary.opacity(0.5)).padding(16) }
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 150)
                            .padding(4)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary, lineWidth: 2))
                    }
                }
                
                // 4. 画像（任意）
                photoSection
                
                // 5. ボイス（任意）
                voiceSection

                if let errorMessage { Text(errorMessage).foregroundColor(.red).font(.footnote) }
                Spacer()
            }
            .padding()
        }
        .navigationTitle(isEditing ? "編集 / 再公開" : "新規投稿")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await submit() } } label: {
                    if isLoading { ProgressView() } else { Text(isEditing ? "更新" : "投稿").fontWeight(.bold) }
                }
                .disabled(!canSubmit)
            }
        }
        .onAppear { requestMicrophonePermission() }
        .onDisappear { audioPlayer?.pause() }
    }
    
    // UI Parts
    var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("画像（最大5枚）").font(.headline)
                Spacer()
                if remainingImageUrls.count + newSelectedImages.count > 0 {
                    Text("\(remainingImageUrls.count + newSelectedImages.count) / 5").font(.caption).foregroundColor(.secondary)
                }
            }
            if !remainingImageUrls.isEmpty || !newSelectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(remainingImageUrls, id: \.self) { url in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: url)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                                    .frame(width: 100, height: 100).clipped().cornerRadius(8)
                                Button { removeExistingImage(url: url) } label: { XMarkButton() }.padding(4)
                            }
                        }
                        ForEach(newSelectedImages.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: newSelectedImages[i]).resizable().scaledToFill()
                                    .frame(width: 100, height: 100).clipped().cornerRadius(8)
                                Button { removeNewImage(at: i) } label: { XMarkButton() }.padding(4)
                            }
                        }
                    }
                }
            }
            PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5 - (remainingImageUrls.count + newSelectedImages.count), matching: .images, photoLibrary: .shared()) {
                HStack { Image(systemName: "photo"); Text("画像を追加") }
                    .frame(maxWidth: .infinity).padding().background(Color(uiColor: .secondarySystemBackground)).cornerRadius(8)
            }
            .disabled(remainingImageUrls.count + newSelectedImages.count >= 5)
        }
        .onChange(of: selectedPhotoItems) { _, new in loadNewImages(from: new) }
    }
    
    var voiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ボイスメッセージ（任意）").font(.headline)
            if let _ = recordedFileURL {
                voicePlaybackView(title: "録音済み", onDelete: deleteRecording)
            } else if isEditing && editingMessage?.voice_url != nil && !isExistingVoiceDeleted {
                if let u = URL(string: editingMessage!.voice_url!) {
                    voicePlaybackView(title: "既存ボイス", onDelete: { isExistingVoiceDeleted = true }, playUrl: u)
                }
            } else {
                Button { isRecording ? stopRecording() : startRecording() } label: {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .resizable().frame(width: 44, height: 44).foregroundColor(isRecording ? .red : .blue)
                        Text(isRecording ? "録音中..." : "録音する")
                    }
                }
            }
        }
        .padding().background(Color(uiColor: .secondarySystemBackground)).cornerRadius(8)
    }

    // Logic
    private func XMarkButton() -> some View { Image(systemName: "xmark.circle.fill").foregroundColor(.white).background(Color.black.opacity(0.5).clipShape(Circle())) }
    
    private func voicePlaybackView(title: String, onDelete: @escaping () -> Void, playUrl: URL? = nil) -> some View {
        HStack {
            Button { if isPlayingPreview { stopPlayback() } else { if let u = playUrl ?? recordedFileURL { startPlayback(url: u) } } } label: {
                Image(systemName: isPlayingPreview ? "stop.circle.fill" : "play.circle.fill").resizable().frame(width: 44, height: 44).foregroundColor(.blue)
            }
            Text(title).font(.subheadline)
            Spacer()
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash").foregroundColor(.red) }
        }
    }

    private func removeExistingImage(url: String) { remainingImageUrls.removeAll { $0 == url } }
    private func removeNewImage(at index: Int) { newSelectedImages.remove(at: index); if index < selectedPhotoItems.count { selectedPhotoItems.remove(at: index) } }
    private func loadNewImages(from items: [PhotosPickerItem]) { Task { var imgs: [UIImage] = []; for item in items { if let d = try? await item.loadTransferable(type: Data.self), let i = UIImage(data: d) { imgs.append(i) } }; await MainActor.run { newSelectedImages = imgs } } }
    private func requestMicrophonePermission() { AVAudioSession.sharedInstance().requestRecordPermission { _ in } }
    private func startRecording() { if isEditing && editingMessage?.voice_url != nil { isExistingVoiceDeleted = true }; try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default); try? AVAudioSession.sharedInstance().setActive(true); let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp.m4a"); let set: [String:Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 12000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]; audioRecorder = try? AVAudioRecorder(url: url, settings: set); audioRecorder?.record(); withAnimation { isRecording = true } }
    private func stopRecording() { audioRecorder?.stop(); withAnimation { isRecording = false; recordedFileURL = audioRecorder?.url } }
    private func deleteRecording() { recordedFileURL = nil }
    private func startPlayback(url: URL) { let item = AVPlayerItem(url: url); if audioPlayer == nil { audioPlayer = AVPlayer(playerItem: item) } else { audioPlayer?.replaceCurrentItem(with: item) }; audioPlayer?.play(); isPlayingPreview = true; NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: audioPlayer?.currentItem, queue: .main) { _ in self.isPlayingPreview = false; self.audioPlayer?.seek(to: .zero) } }
    private func stopPlayback() { audioPlayer?.pause(); isPlayingPreview = false }

    private var canSubmit: Bool {
        let isKeywordValid = !keyword.trimmingCharacters(in: .whitespaces).isEmpty
        let isPasscodeValid = !passcode.isEmpty
        let hasBody = !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
        let hasVoice = recordedFileURL != nil || (isEditing && editingMessage?.voice_url != nil && !isExistingVoiceDeleted)
        let hasImage = !newSelectedImages.isEmpty || !remainingImageUrls.isEmpty
        return isKeywordValid && isPasscodeValid && (hasBody || hasVoice || hasImage)
    }

    private func submit() async {
        errorMessage = nil; isLoading = true; defer { isLoading = false }
        let k = keyword.trimmingCharacters(in: .whitespaces)
        let b = bodyText.trimmingCharacters(in: .whitespaces)
        var vd: Data? = nil; if let u = recordedFileURL, let d = try? Data(contentsOf: u) { vd = d }
        var id: [Data] = []; for img in newSelectedImages { if let d = img.jpegData(compressionQuality: 0.8) { id.append(d) } }

        do {
            let res: Message
            if let editing = editingMessage {
                res = try await service.updateMessage(
                    message: editing, keyword: k, body: b,
                    shouldDeleteVoice: isExistingVoiceDeleted, newVoiceData: vd,
                    remainingImageUrls: remainingImageUrls, newImagesData: id,
                    passcode: passcode, is4Digit: is4DigitMode
                )
            } else {
                res = try await service.createMessage(
                    keyword: k, body: b, voiceData: vd, imagesData: id,
                    passcode: passcode, is4Digit: is4DigitMode
                )
            }
            await MainActor.run { onCompleted(res); dismiss() }
        } catch MessageServiceError.keywordAlreadyExists {
            await MainActor.run { errorMessage = "この合言葉は使用済みです" }
        } catch {
            print("==========================================")
            print("投稿エラー詳細: \(error)")
            print("==========================================")
            await MainActor.run { errorMessage = "処理に失敗しました。時間をおいて再度お試しください。" }
        }
    }
}
