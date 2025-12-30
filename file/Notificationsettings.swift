import Foundation

struct NotificationSettings: Codable {
    let id: UUID
    let user_id: UUID
    var push_enabled: Bool
    var notify_on_stolen: Bool
    var notify_on_attempts: Bool
    var attempt_threshold: Int
    let created_at: Date
    let updated_at: Date
}
