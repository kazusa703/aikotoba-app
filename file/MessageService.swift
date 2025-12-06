import Foundation
import Supabase

// MARK: - Error Types
enum MessageServiceError: Error {
    case notFound
    case keywordAlreadyExists
    case notSignedIn
    case unknown(Error)
    case uploadFailed
}

// MARK: - Parameter Structs

struct InsertMessagePayload: Encodable, Sendable {
    let keyword: String
    let body: String
    let owner_token: String
    let user_id: UUID?
    let voice_url: String?
    let image_urls: [String]?
    let creator_id: UUID?
    let passcode: String
    let is_4_digit: Bool
    let is_hidden: Bool
}

struct UpdateMessagePayload: Encodable, Sendable {
    let keyword: String
    let body: String
    let voice_url: String?
    let image_urls: [String]?
    let passcode: String?
    let is_4_digit: Bool?
    let is_hidden: Bool?
}

struct InsertReportPayload: Encodable, Sendable {
    let message_id: UUID
}

// MARK: - Service Class

final class MessageService {

    private var supabase: SupabaseClient {
        SupabaseClientManager.shared.client
    }

    private var ownerToken: String {
        OwnerTokenManager.shared.getOrCreateToken()
    }
    
    private let projectUrlString = "https://mdlhncrhfluikvnixryi.supabase.co"
    
    // ★追加: 共通のカスタムデコーダー (ミリ秒と通常のISO8601両対応)
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            // 1. ミリ秒付き (例: 2023-10-10T10:00:00.123+00:00) を試す
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateStr) { return date }
            
            // 2. 通常 (例: 2023-10-10T10:00:00Z) を試す
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateStr) { return date }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateStr)")
        }
        return decoder
    }()

    // MARK: - Fetch

    func fetchMessage(by keyword: String) async throws -> Message {
        do {
            let response = try await supabase
                .from("messages")
                .select()
                .eq("keyword", value: keyword)
                .eq("is_hidden", value: false)
                .limit(1)
                .single()
                .execute()

            // ★共通デコーダーを使用
            return try decoder.decode(Message.self, from: response.data)

        } catch let error as PostgrestError {
            if error.code == "PGRST116" || error.message.lowercased().contains("not found") {
                throw MessageServiceError.notFound
            }
            print("Supabase Error: \(error)")
            throw MessageServiceError.unknown(error)
        } catch {
            throw MessageServiceError.unknown(error)
        }
    }
    
    // MARK: - Steal (奪う / ロック解除)

    func attemptSteal(messageId: UUID, guess: String) async throws -> String {
        let params: [String: String] = [
            "target_message_id": messageId.uuidString,
            "input_passcode": guess,
            "new_owner_token": ownerToken
        ]
        
        do {
            let response: String = try await supabase
                .database
                .rpc("attempt_steal", params: params)
                .execute()
                .value
            
            return response
        } catch {
            print("Steal error: \(error)")
            throw error
        }
    }
    
    // MARK: - Increment View Count

    func incrementViewCount(for messageId: UUID) async {
        do {
            try await supabase
                .database
                .rpc(
                    "increment_view_count",
                    params: ["row_id": messageId]
                )
                .execute()
        } catch {
            print("View count error: \(error)")
        }
    }

    // MARK: - Create

    func createMessage(
        keyword: String,
        body: String,
        voiceData: Data?,
        imagesData: [Data]?,
        passcode: String,
        is4Digit: Bool
    ) async throws -> Message {
        
        var voiceUrl: String? = nil
        if let voiceData {
            voiceUrl = try await uploadFile(
                data: voiceData,
                bucketName: "voice-messages",
                fileExtension: "m4a",
                contentType: "audio/m4a"
            )
        }
        
        var imageUrls: [String]? = nil
        if let imagesData, !imagesData.isEmpty {
            var urls: [String] = []
            for data in imagesData {
                let url = try await uploadFile(
                    data: data,
                    bucketName: "images",
                    fileExtension: "jpg",
                    contentType: "image/jpeg"
                )
                urls.append(url)
            }
            imageUrls = urls
        }

        let userId = supabase.auth.currentUser?.id
        
        let payload = InsertMessagePayload(
            keyword: keyword,
            body: body,
            owner_token: ownerToken,
            user_id: userId,
            voice_url: voiceUrl,
            image_urls: imageUrls,
            creator_id: userId,
            passcode: passcode,
            is_4_digit: is4Digit,
            is_hidden: false
        )

        do {
            let response = try await supabase
                .from("messages")
                .insert(payload, returning: .representation)
                .single()
                .execute()

            // ★共通デコーダーを使用
            return try decoder.decode(Message.self, from: response.data)

        } catch let error as PostgrestError {
            if error.message.contains("duplicate key value") ||
                error.message.contains("messages_keyword_unique") {
                throw MessageServiceError.keywordAlreadyExists
            }
            throw MessageServiceError.unknown(error)
        } catch {
            throw MessageServiceError.unknown(error)
        }
    }
    
    // MARK: - Update

    func updateMessage(
        message: Message,
        keyword: String,
        body: String,
        shouldDeleteVoice: Bool,
        newVoiceData: Data?,
        remainingImageUrls: [String],
        newImagesData: [Data],
        passcode: String?,
        is4Digit: Bool?
    ) async throws -> Message {
        
        var finalVoiceUrl: String? = message.voice_url
        
        if shouldDeleteVoice || newVoiceData != nil {
            if let oldUrl = message.voice_url {
                try? await deleteFile(url: oldUrl)
            }
            finalVoiceUrl = nil
        }
        
        if let newVoiceData {
            finalVoiceUrl = try await uploadFile(
                data: newVoiceData,
                bucketName: "voice-messages",
                fileExtension: "m4a",
                contentType: "audio/m4a"
            )
        }
        
        var finalImageUrls: [String] = remainingImageUrls
        
        if let oldUrls = message.image_urls {
            let urlsToDelete = oldUrls.filter { !remainingImageUrls.contains($0) }
            for url in urlsToDelete {
                try? await deleteFile(url: url)
            }
        }
        
        for data in newImagesData {
            let url = try await uploadFile(
                data: data,
                bucketName: "images",
                fileExtension: "jpg",
                contentType: "image/jpeg"
            )
            finalImageUrls.append(url)
        }
        
        let payload = UpdateMessagePayload(
            keyword: keyword,
            body: body,
            voice_url: finalVoiceUrl,
            image_urls: finalImageUrls.isEmpty ? nil : finalImageUrls,
            passcode: passcode,
            is_4_digit: is4Digit,
            is_hidden: false
        )
        
        do {
            let response = try await supabase
                .from("messages")
                .update(payload)
                .eq("id", value: message.id)
                .select()
                .single()
                .execute()
            
            // ★共通デコーダーを使用
            return try decoder.decode(Message.self, from: response.data)
            
        } catch let error as PostgrestError {
            if error.message.contains("duplicate key value") {
                throw MessageServiceError.keywordAlreadyExists
            }
            print("Update failed: \(error)")
            throw MessageServiceError.unknown(error)
        } catch {
            print("Update failed: \(error)")
            throw MessageServiceError.unknown(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func uploadFile(
        data: Data,
        bucketName: String,
        fileExtension: String,
        contentType: String
    ) async throws -> String {
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        do {
            _ = try await supabase.storage
                .from(bucketName)
                .upload(
                    fileName,
                    data: data,
                    options: FileOptions(contentType: contentType)
                )
            
            let publicURL = "\(projectUrlString)/storage/v1/object/public/\(bucketName)/\(fileName)"
            return publicURL
        } catch {
            print("Upload error for \(bucketName): \(error)")
            throw MessageServiceError.uploadFailed
        }
    }
    
    private func deleteFile(url: String) async throws {
        guard let urlObj = URL(string: url),
              let projectUrl = URL(string: projectUrlString),
              urlObj.host == projectUrl.host else { return }
        
        let pathComponents = urlObj.pathComponents
        guard pathComponents.count >= 3 else { return }
        
        let bucketName = pathComponents[pathComponents.count - 2]
        let fileName = pathComponents.last!
        
        do {
            _ = try await supabase.storage
                .from(bucketName)
                .remove(paths: [fileName])
        } catch {
            print("Failed to delete file: \(error)")
        }
    }

    // MARK: - Other Actions
    
    func reportMessage(_ message: Message) async throws {
        let payload = InsertReportPayload(message_id: message.id)
        _ = try await supabase.from("reports").insert(payload).execute()
    }

    func deleteMessage(_ message: Message) async throws {
        _ = try await supabase.from("messages").delete().eq("id", value: message.id).execute()
    }
    
    // MARK: - My Messages
    
    func fetchMyMessages() async throws -> [Message] {
        guard let userId = supabase.auth.currentUser?.id else {
            throw MessageServiceError.notSignedIn
        }
        
        do {
            let response = try await supabase
                .from("messages")
                .select()
                .or("user_id.eq.\(userId),creator_id.eq.\(userId)")
                .order("created_at", ascending: false)
                .execute()

            // ★共通デコーダーを使用
            return try decoder.decode([Message].self, from: response.data)
        } catch {
            print("Supabase fetchMyMessages error: \(error)")
            throw MessageServiceError.unknown(error)
        }
    }

    // MARK: - Owner Check
    
    func isOwner(of message: Message) -> Bool {
        return message.ownerToken == ownerToken
    }
}
