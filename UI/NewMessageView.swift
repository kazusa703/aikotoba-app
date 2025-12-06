import SwiftUI
import AVFoundation
import PhotosUI

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var keyword: String = ""
    @State private var bodyText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // 録音関連
    @State private var audioRecorder: AVAudioRecorder?
    @State private var isRecording = false
    @State private var recordedFileURL: URL?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingPreview = false
    
    // 複数画像用のState
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    let service: MessageService
    let onCreated: (Message) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // --- 合言葉 ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("合言葉")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("世界で一つだけ", text: $keyword)
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary, lineWidth: 2)
                        )
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
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
                            .frame(minHeight: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary, lineWidth: 2)
                            )
                    }
                }
                
                // --- 画像セクション（複数対応） ---
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("画像（最大5枚）")
                            .font(.headline)
                        Spacer()
                        // 枚数表示
                        if !selectedImages.isEmpty {
                            Text("\(selectedImages.count) / 5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !selectedImages.isEmpty {
                        // 横スクロールで選択した画像を表示
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipped()
                                            .cornerRadius(8)
                                        
                                        // 削除ボタン
                                        Button {
                                            removeImage(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.5).clipShape(Circle()))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 画像選択ボタン
                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 5,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(selectedImages.isEmpty ? "画像を選択" : "画像を変更する")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .onChange(of: selectedPhotoItems) { newItems in
                    Task {
                        var loadedImages: [UIImage] = []
                        for item in newItems {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                loadedImages.append(image)
                            }
                        }
                        // メインスレッドで更新
                        await MainActor.run {
                            selectedImages = loadedImages
                        }
                    }
                }
                
                // --- ボイスメッセージ ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("ボイスメッセージ（任意）")
                        .font(.headline)
                    
                    HStack {
                        if let _ = recordedFileURL {
                            Button {
                                if isPlayingPreview {
                                    stopPlayback()
                                } else {
                                    startPlayback()
                                }
                            } label: {
                                Image(systemName: isPlayingPreview ? "stop.circle.fill" : "play.circle.fill")
                                    .resizable()
                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.blue)
                            }
                            Text("録音済み")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                deleteRecording()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        } else {
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
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("新しいメッセージ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await create() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("投稿")
                            .fontWeight(.bold)
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .onAppear {
            requestMicrophonePermission()
        }
    }
    
    // 画像削除処理
    private func removeImage(at index: Int) {
        selectedImages.remove(at: index)
        selectedPhotoItems.remove(at: index)
    }

    private var canSubmit: Bool {
        !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func create() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        var voiceData: Data? = nil
        if let url = recordedFileURL, let data = try? Data(contentsOf: url) {
            voiceData = data
        }
        
        // ★修正点: 複数画像のデータ変換
        var imagesData: [Data] = []
        for image in selectedImages {
            if let data = image.jpegData(compressionQuality: 0.8) {
                imagesData.append(data)
            }
        }

        do {
            // ★修正点: 引数名を imagesData に変更し、配列を渡す
            let message = try await service.createMessage(
                keyword: trimmedKeyword,
                body: trimmedBody,
                voiceData: voiceData,
                imagesData: imagesData
            )
            await MainActor.run {
                onCreated(message)
                dismiss()
            }
        } catch MessageServiceError.keywordAlreadyExists {
            await MainActor.run {
                errorMessage = "この合言葉はすでに使われています。別の合言葉を試してください。"
            }
        } catch {
            await MainActor.run {
                errorMessage = "投稿に失敗しました。時間をおいて再度お試しください。"
            }
        }
    }
    
    // MARK: - Audio Logic (変更なし)
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
    }
    private func startRecording() {
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
    private func deleteRecording() { recordedFileURL = nil; audioRecorder = nil }
    private func startPlayback() {
        guard let url = recordedFileURL else { return }
        do { audioPlayer = try AVAudioPlayer(contentsOf: url); audioPlayer?.play(); isPlayingPreview = true } catch { print("再生エラー: \(error)") }
    }
    private func stopPlayback() { audioPlayer?.stop(); isPlayingPreview = false }
}
