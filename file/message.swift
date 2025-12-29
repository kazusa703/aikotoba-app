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
    var stolen_count: Int
    var failed_count: Int

    let creator_id: UUID?
    let passcode: String
    let is_4_digit: Bool  // 互換性のため残す
    let passcode_length: Int  // 新規追加: 3〜10
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
        case stolen_count
        case failed_count
        case creator_id
        case passcode
        case is_4_digit
        case passcode_length
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
        stolen_count = try container.decodeIfPresent(Int.self, forKey: .stolen_count) ?? 0
        failed_count = try container.decodeIfPresent(Int.self, forKey: .failed_count) ?? 0
        
        is_hidden = try container.decodeIfPresent(Bool.self, forKey: .is_hidden) ?? false
        is_4_digit = try container.decodeIfPresent(Bool.self, forKey: .is_4_digit) ?? false
        passcode = try container.decodeIfPresent(String.self, forKey: .passcode) ?? "000"
        creator_id = try container.decodeIfPresent(UUID.self, forKey: .creator_id)
        user_id = try container.decodeIfPresent(UUID.self, forKey: .user_id)
        
        // passcode_lengthがない場合はis_4_digitから推測
        if let length = try container.decodeIfPresent(Int.self, forKey: .passcode_length) {
            passcode_length = length
        } else {
            passcode_length = is_4_digit ? 4 : 3
        }
        
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
    
    // 桁数に応じたセキュリティレベル表示
    var securityLevelText: String {
        switch passcode_length {
        case 3: return "3桁"
        case 4: return "4桁"
        case 5: return "5桁"
        case 6: return "6桁"
        case 7: return "7桁"
        case 8: return "8桁"
        case 9: return "9桁"
        case 10: return "10桁"
        default: return "\(passcode_length)桁"
        }
    }
    
    // 桁数に応じた色
    var securityColor: String {
        switch passcode_length {
        case 3: return "orange"
        case 4: return "yellow"
        case 5: return "green"
        case 6: return "blue"
        case 7: return "purple"
        case 8...10: return "pink"
        default: return "gray"
        }
    }
    
    // 組み合わせ数
    var combinationCount: Int {
        return Int(pow(10.0, Double(passcode_length)))
    }
    
    var combinationCountText: String {
        let count = combinationCount
        if count >= 1_000_000_000 {
            return "\(count / 1_000_000_000)0億通り"
        } else if count >= 100_000_000 {
            return "\(count / 100_000_000)億通り"
        } else if count >= 10_000_000 {
            return "\(count / 10_000_000)千万通り"
        } else if count >= 1_000_000 {
            return "\(count / 1_000_000)百万通り"
        } else if count >= 10_000 {
            return "\(count / 10_000)万通り"
        } else if count >= 1_000 {
            return "\(count / 1_000)千通り"
        }
        return "\(count)通り"
    }
}
