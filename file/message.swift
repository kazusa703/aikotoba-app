import Foundation

struct Message: Identifiable, Decodable, Sendable {
    let id: UUID
    let keyword: String
    let body: String
    let ownerToken: String
    let createdAt: Date
    let voice_url: String?
    let image_urls: [String]?
    
    // 閲覧数はアプリ内で +1 するため var にしています
    var view_count: Int

    // ★奪い合いゲーム機能用の項目
    let creator_id: UUID? // 初代作成者のID
    let passcode: String  // 設定された暗証番号
    let is_4_digit: Bool  // 4桁モードかどうか
    let is_hidden: Bool   // 一時的に非公開になっているか

    enum CodingKeys: String, CodingKey {
        case id
        case keyword
        case body
        case ownerToken = "owner_token"
        case createdAt = "created_at"
        case voice_url
        case image_urls
        case view_count
        
        // Supabaseのカラム名と一致させる
        case creator_id
        case passcode
        case is_4_digit
        case is_hidden
    }
    
    // ★カスタムデコード（日付形式やNULL許容に対応）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        keyword = try container.decode(String.self, forKey: .keyword)
        body = try container.decode(String.self, forKey: .body)
        ownerToken = try container.decode(String.self, forKey: .ownerToken)
        voice_url = try container.decodeIfPresent(String.self, forKey: .voice_url)
        image_urls = try container.decodeIfPresent([String].self, forKey: .image_urls)
        
        // オプショナル値の安全なデコード（デフォルト値設定）
        view_count = try container.decodeIfPresent(Int.self, forKey: .view_count) ?? 0
        is_hidden = try container.decodeIfPresent(Bool.self, forKey: .is_hidden) ?? false
        is_4_digit = try container.decodeIfPresent(Bool.self, forKey: .is_4_digit) ?? false
        passcode = try container.decodeIfPresent(String.self, forKey: .passcode) ?? "000"
        creator_id = try container.decodeIfPresent(UUID.self, forKey: .creator_id)
        
        // 日付のデコード（ISO8601形式対応）
        // Supabaseはミリ秒を含む場合があるため、formatOptionsを指定
        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            createdAt = date
        } else {
            // ミリ秒がない場合のフォールバック
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                createdAt = date
            } else {
                // 最終手段：現在時刻
                createdAt = Date()
            }
        }
    }
}
