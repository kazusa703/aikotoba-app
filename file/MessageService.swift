import Foundation
import Supabase

enum MessageServiceError: Error {
    case notFound
    case keywordAlreadyExists
    case notSignedIn
    case unknown(Error)
    case uploadFailed
}

final class MessageService {

    private var supabase: SupabaseClient {
        SupabaseClientManager.shared.client
    }

    private var ownerToken: String {
        OwnerTokenManager.shared.getOrCreateToken()
    }
    
    // プロジェクトURL
    private let projectUrlString = "https://mdlhncrhfluikvnixryi.supabase.co"

    // MARK: - Fetch

    func fetchMessage(by keyword: String) async throws -> Message {
        do {
            let response = try await supabase
                .from("messages")
                .select()
                .eq("keyword", value: keyword)
                .limit(1)
                .single()
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let message = try decoder.decode(Message.self, from: response.data)
            return message

        } catch let error as PostgrestError {
            if error.code == "PGRST116" ||
               error.message.lowercased().contains("not found") ||
               error.code == "404" || error.code == "406" {
                throw MessageServiceError.notFound
            }
            print("Supabase Error: \(error)")
            throw MessageServiceError.unknown(error)

        } catch {
            print("Unknown Error: \(error)")
            throw MessageServiceError.unknown(error)
        }
    }

    // MARK: - Create (複数画像対応)

    func createMessage(keyword: String, body: String, voiceData: Data?, imagesData: [Data]?) async throws -> Message {
        
        // 1. ボイスのアップロード
        var voiceUrl: String? = nil
        if let voiceData = voiceData {
            voiceUrl = try await uploadFile(
                data: voiceData,
                bucketName: "voice-messages",
                fileExtension: "m4a",
                contentType: "audio/m4a"
            )
        }
        
        // 2. 画像のアップロード（複数枚をループ処理）
        var imageUrls: [String]? = nil
        if let imagesData = imagesData, !imagesData.isEmpty {
            var urls: [String] = []
            for data in imagesData {
                // JPEGとしてアップロード
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

        // 3. データベースに保存
        struct InsertMessage: Encodable {
            let keyword: String
            let body: String
            let owner_token: String
            let user_id: UUID?
            let voice_url: String?
            let image_urls: [String]? // 配列に変更
        }

        let userId = supabase.auth.currentUser?.id

        let payload = InsertMessage(
            keyword: keyword,
            body: body,
            owner_token: ownerToken,
            user_id: userId,
            voice_url: voiceUrl,
            image_urls: imageUrls
        )

        do {
            let response = try await supabase
                .from("messages")
                .insert(payload, returning: .representation)
                .single()
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let message = try decoder.decode(Message.self, from: response.data)
            return message

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
    
    // MARK: - Upload File
    
    private func uploadFile(data: Data, bucketName: String, fileExtension: String, contentType: String) async throws -> String {
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        
        do {
            _ = try await supabase.storage
                .from(bucketName)
                .upload(
                    path: fileName,
                    file: data,
                    options: FileOptions(contentType: contentType)
                )
            
            let publicURL = "\(projectUrlString)/storage/v1/object/public/\(bucketName)/\(fileName)"
            return publicURL
            
        } catch {
            print("Upload error for \(bucketName): \(error)")
            throw MessageServiceError.uploadFailed
        }
    }

    // MARK: - Report
    // (変更なし)
    func reportMessage(_ message: Message) async throws {
        struct InsertReport: Encodable {
            let message_id: UUID
        }
        let payload = InsertReport(message_id: message.id)
        _ = try await supabase.from("reports").insert(payload).execute()
    }

    // MARK: - Delete
    // (変更なし)
    func deleteMessage(_ message: Message) async throws {
        _ = try await supabase.from("messages").delete().eq("id", value: message.id).execute()
    }
    
    // MARK: - My Messages
    // (変更なし)
    func fetchMyMessages() async throws -> [Message] {
        guard let userId = supabase.auth.currentUser?.id else {
            throw MessageServiceError.notSignedIn
        }
        do {
            let response = try await supabase
                .from("messages")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let messages = try decoder.decode([Message].self, from: response.data)
            return messages
        } catch {
            print("Supabase fetchMyMessages error: \(error)")
            throw MessageServiceError.unknown(error)
        }
    }

    // MARK: - Owner
    func isOwner(of message: Message) -> Bool {
        return message.ownerToken == ownerToken
    }
}
