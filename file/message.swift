import Foundation

struct Message: Identifiable, Decodable {
    let id: UUID
    let keyword: String
    let body: String
    let ownerToken: String
    let createdAt: Date
    let voice_url: String?
    // ★変更: String? から [String]? (配列) に変更
    let image_urls: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case keyword
        case body
        case ownerToken = "owner_token"
        case createdAt = "created_at"
        case voice_url
        // ★変更: カラム名 image_urls に合わせる
        case image_urls = "image_urls"
    }
}
