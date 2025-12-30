import Foundation
import SwiftUI

struct AppNotification: Identifiable, Decodable {
    let id: UUID
    let user_id: UUID
    let title: String
    let body: String
    let type: String  // "stolen", "failed_attempt", "info"
    let related_message_id: UUID?
    let is_read: Bool
    let created_at: Date

    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case title
        case body
        case type
        case related_message_id
        case is_read
        case created_at
    }
    
    // 通知タイプに応じたアイコン
    var icon: String {
        switch type {
        case "stolen":
            return "exclamationmark.triangle.fill"
        case "failed_attempt":
            return "shield.fill"
        default:
            return "bell.fill"
        }
    }
    
    // 通知タイプに応じた色
    var color: Color {
        switch type {
        case "stolen":
            return .red
        case "failed_attempt":
            return .orange
        default:
            return .blue
        }
    }
}
