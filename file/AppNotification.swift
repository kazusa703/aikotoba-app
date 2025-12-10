import Foundation

struct AppNotification: Identifiable, Decodable {
    let id: UUID
    let title: String
    let body: String
    let is_read: Bool
    let created_at: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case is_read
        case created_at
    }
}
