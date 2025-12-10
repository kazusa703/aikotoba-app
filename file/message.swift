import Foundation

struct Message: Identifiable, Decodable, Sendable {
    let id: UUID
    let keyword: String
    let body: String
    let ownerToken: String
    let createdAt: Date
    let voice_url: String?
    let image_urls: [String]?
    
    var view_count: Int
    
    // ★追加: 新しいカウント
    var stolen_count: Int
    var failed_count: Int

    let creator_id: UUID?
    let passcode: String
    let is_4_digit: Bool
    let is_hidden: Bool
    let user_id: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case keyword
        case body
        case ownerToken = "owner_token"
        case createdAt = "created_at"
        case voice_url
        case image_urls = "image_urls"
        case view_count
        
        // ★追加
        case stolen_count
        case failed_count
        
        case creator_id
        case passcode
        case is_4_digit
        case is_hidden
        case user_id
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        keyword = try container.decode(String.self, forKey: .keyword)
        body = try container.decode(String.self, forKey: .body)
        ownerToken = try container.decode(String.self, forKey: .ownerToken)
        voice_url = try container.decodeIfPresent(String.self, forKey: .voice_url)
        image_urls = try container.decodeIfPresent([String].self, forKey: .image_urls)
        
        view_count = try container.decodeIfPresent(Int.self, forKey: .view_count) ?? 0
        
        // ★追加: デフォルト値0でデコード
        stolen_count = try container.decodeIfPresent(Int.self, forKey: .stolen_count) ?? 0
        failed_count = try container.decodeIfPresent(Int.self, forKey: .failed_count) ?? 0
        
        is_hidden = try container.decodeIfPresent(Bool.self, forKey: .is_hidden) ?? false
        is_4_digit = try container.decodeIfPresent(Bool.self, forKey: .is_4_digit) ?? false
        passcode = try container.decodeIfPresent(String.self, forKey: .passcode) ?? "000"
        creator_id = try container.decodeIfPresent(UUID.self, forKey: .creator_id)
        user_id = try container.decodeIfPresent(UUID.self, forKey: .user_id)
        
        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            createdAt = date
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                createdAt = date
            } else {
                createdAt = Date()
            }
        }
    }
}
