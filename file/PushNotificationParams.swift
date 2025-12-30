import Foundation

// MARK: - Push Notification Parameter Structs

struct RegisterTokenParams: Encodable, Sendable {
    let p_device_token: String
    let p_platform: String
}

struct RemoveTokenParams: Encodable, Sendable {
    let p_device_token: String
}

struct UpdateSettingsParams: Encodable, Sendable {
    let p_push_enabled: Bool?
    let p_notify_on_stolen: Bool?
    let p_notify_on_attempts: Bool?
    let p_attempt_threshold: Int?
}
