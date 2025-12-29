import SwiftUI
import PhotosUI
import AVFoundation

struct NewMessageView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeKit = StoreKitManager.shared
    
    let service: MessageService
    var editingMessage: Message?
    var onCompleted: ((Message) -> Void)?
    
    // Form State
    @State private var keyword = ""
    @State private var messageBody = ""
    @State private var passcode = ""
    @State private var selectedLength: Int = 3
    
    // Photo State
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImagesData: [Data] = []
    @State private var existingImageUrls: [String] = []
    
    // Voice State
    @State private var voiceData: Data?
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var shouldDeleteVoice = false
    
    // UI State
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingUpgradeSheet = false
    @State private var upgradeTargetLength = 4
    
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
    
    private var isEditing: Bool { editingMessage != nil }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Photo Section
                photoSection
                
                // MARK: - Keyword Section
                keywordSection
                
                // MARK: - Body Section
                bodySection
                
                // MARK: - Passcode Section
                passcodeSection
                
                // MARK: - Voice Section
                voiceSection
                
                // MARK: - Error
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
                Button("キャンセル") { dismiss() }
                    .foregroundColor(.primary)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(isEditing ? "更新" : "投稿")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(canSubmit ? instagramGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(20)
                    }
                }
                .disabled(!canSubmit || isLoading)
            }
        }
        .onAppear { loadEditingMessage() }
        .onChange(of: selectedItems) { _, items in
            Task { await loadImages(from: items) }
        }
        .sheet(isPresented: $showingUpgradeSheet) {
            upgradeSheetView
        }
    }
    
    private var canSubmit: Bool {
        !keyword.isEmpty && passcode.count == selectedLength
    }
    
    // MARK: - Photo Section
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("写真")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Existing images
                    ForEach(existingImageUrls, id: \.self) { url in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 100, height: 100)
                            .cornerRadius(12)
                            .clipped()
                            
                            Button {
                                existingImageUrls.removeAll { $0 == url }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                    
                    // New images
                    ForEach(selectedImagesData.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            if let uiImage = UIImage(data: selectedImagesData[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(12)
                                    .clipped()
                            }
                            
                            Button {
                                selectedImagesData.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                    
                    // Add button
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                        VStack {
                            Image(systemName: "plus")
                                .font(.title2)
                            Text("追加")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .frame(width: 100, height: 100)
                        .background(subtleGray)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Keyword Section
    private var keywordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("合言葉")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            TextField("秘密の合言葉を入力", text: $keyword)
                .padding(16)
                .background(isEditing ? Color.gray.opacity(0.1) : subtleGray)
                .cornerRadius(12)
                .disabled(isEditing)
            
            if isEditing {
                Text("合言葉は変更できません")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
                TextEditor(text: $messageBody)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(subtleGray)
                    .cornerRadius(12)
                
                if messageBody.isEmpty {
                    Text("メッセージを入力（任意）")
                        .foregroundColor(.gray.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Passcode Section
    private var passcodeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("暗証番号")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Current length badge
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                    Text("\(selectedLength)桁")
                }
                .font(.caption)
                .foregroundColor(securityColor(for: selectedLength))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(securityColor(for: selectedLength).opacity(0.1))
                )
            }
            
            // Length selection (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(3...10, id: \.self) { length in
                        lengthButton(length: length)
                    }
                }
            }
            
            // Passcode input
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.gray)
                
                TextField(String(repeating: "0", count: selectedLength), text: $passcode)
                    .keyboardType(.numberPad)
                    .font(.title3)
            }
            .padding(16)
            .background(subtleGray)
            .cornerRadius(12)
            .onChange(of: passcode) { _, val in
                if val.count > selectedLength {
                    passcode = String(val.prefix(selectedLength))
                }
            }
            .onChange(of: selectedLength) { _, _ in
                passcode = ""
            }
            
            // Info text
            Text(securityInfoText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private func lengthButton(length: Int) -> some View {
        let isSelected = selectedLength == length
        let isFree = length == 3
        let price = storeKit.displayPrice(for: length)
        
        return Button {
            if isFree || isEditing {
                selectedLength = length
            } else {
                upgradeTargetLength = length
                showingUpgradeSheet = true
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(length)桁")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .regular)
                
                Text(isFree ? "無料" : price)
                    .font(.caption2)
                    .foregroundColor(isFree ? .green : .orange)
            }
            .frame(width: 60, height: 50)
            .background(isSelected ? securityColor(for: length).opacity(0.2) : Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? securityColor(for: length) : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .foregroundColor(.primary)
    }
    
    private var securityInfoText: String {
        let count = Int(pow(10.0, Double(selectedLength)))
        if count >= 1_000_000_000 { return "🛡️ 100億通りの組み合わせ - 最高レベルのセキュリティ" }
        if count >= 100_000_000 { return "🛡️ 1億通りの組み合わせ - 極めて強固" }
        if count >= 10_000_000 { return "🛡️ 1,000万通りの組み合わせ - 非常に強固" }
        if count >= 1_000_000 { return "🛡️ 100万通りの組み合わせ - 強固なセキュリティ" }
        if count >= 100_000 { return "🔒 10万通りの組み合わせ - 高いセキュリティ" }
        if count >= 10_000 { return "🔒 1万通りの組み合わせ - 標準的なセキュリティ" }
        return "⚠️ 1,000通りの組み合わせ - 推測されやすい"
    }
    
    private func securityColor(for length: Int) -> Color {
        switch length {
        case 3: return .orange
        case 4: return .yellow
        case 5: return .green
        case 6: return .blue
        case 7: return .purple
        case 8...10: return .pink
        default: return .gray
        }
    }
    
    // MARK: - Voice Section
    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ボイスメッセージ")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if let _ = voiceData {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text("録音済み")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("削除") {
                        voiceData = nil
                        shouldDeleteVoice = true
                    }
                    .foregroundColor(.red)
                }
                .padding(16)
                .background(subtleGray)
                .cornerRadius(12)
            } else if let _ = editingMessage?.voice_url, !shouldDeleteVoice {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                    Text("ボイスメッセージあり")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("削除") {
                        shouldDeleteVoice = true
                    }
                    .foregroundColor(.red)
                }
                .padding(16)
                .background(subtleGray)
                .cornerRadius(12)
            } else {
                Button {
                    toggleRecording()
                } label: {
                    HStack {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title)
                            .foregroundColor(isRecording ? .red : .gray)
                        
                        Text(isRecording ? "録音停止" : "タップして録音")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(subtleGray)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Upgrade Sheet
    private var upgradeSheetView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [securityColor(for: upgradeTargetLength), securityColor(for: upgradeTargetLength).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("\(upgradeTargetLength)桁の暗証番号")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(combinationText(for: upgradeTargetLength) + "の組み合わせ")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(storeKit.displayPrice(for: upgradeTargetLength))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 12) {
                    benefitRow(icon: "shield.fill", text: "強固なセキュリティ")
                    benefitRow(icon: "clock.fill", text: "長期間守りやすい")
                    benefitRow(icon: "star.fill", text: "一度購入すれば何度でも使用可能")
                }
                .padding(20)
                .background(subtleGray)
                .cornerRadius(16)
                
                Spacer()
                
                Button {
                    Task { await purchaseLength() }
                } label: {
                    Text("\(storeKit.displayPrice(for: upgradeTargetLength))で購入")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [securityColor(for: upgradeTargetLength), securityColor(for: upgradeTargetLength).opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            }
            .padding(24)
            .navigationTitle("桁数を増やす")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        showingUpgradeSheet = false
                    }
                }
            }
        }
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(securityColor(for: upgradeTargetLength))
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func combinationText(for length: Int) -> String {
        let count = Int(pow(10.0, Double(length)))
        if count >= 1_000_000_000 { return "100億通り" }
        if count >= 100_000_000 { return "1億通り" }
        if count >= 10_000_000 { return "1,000万通り" }
        if count >= 1_000_000 { return "100万通り" }
        if count >= 100_000 { return "10万通り" }
        if count >= 10_000 { return "1万通り" }
        return "\(count)通り"
    }
    
    // MARK: - Methods
    
    private func loadEditingMessage() {
        guard let message = editingMessage else { return }
        keyword = message.keyword
        messageBody = message.body
        selectedLength = message.passcode_length
        passcode = message.passcode
        existingImageUrls = message.image_urls ?? []
    }
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        selectedImagesData = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                selectedImagesData.append(data)
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Recording error: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        if let url = audioRecorder?.url,
           let data = try? Data(contentsOf: url) {
            voiceData = data
            shouldDeleteVoice = false
        }
    }
    
    private func purchaseLength() async {
        do {
            let purchased = try await storeKit.purchase(length: upgradeTargetLength)
            if purchased {
                await MainActor.run {
                    selectedLength = upgradeTargetLength
                    passcode = ""
                    showingUpgradeSheet = false
                }
            }
        } catch {
            print("Purchase error: \(error)")
        }
    }
    
    private func save() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let message: Message
            
            if let editing = editingMessage {
                message = try await service.updateMessage(
                    message: editing,
                    keyword: keyword,
                    body: messageBody,
                    shouldDeleteVoice: shouldDeleteVoice,
                    newVoiceData: voiceData,
                    remainingImageUrls: existingImageUrls,
                    newImagesData: selectedImagesData,
                    passcode: passcode,
                    passcodeLength: selectedLength
                )
            } else {
                message = try await service.createMessage(
                    keyword: keyword,
                    body: messageBody,
                    voiceData: voiceData,
                    imagesData: selectedImagesData.isEmpty ? nil : selectedImagesData,
                    passcode: passcode,
                    passcodeLength: selectedLength
                )
            }
            
            onCompleted?(message)
            dismiss()
            
        } catch MessageServiceError.keywordAlreadyExists {
            errorMessage = "この合言葉は既に使用されています"
        } catch {
            errorMessage = "エラーが発生しました"
            print("Save error: \(error)")
        }
    }
}
