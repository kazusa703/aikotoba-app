import Foundation
import UserNotifications
import UIKit
import Combine
import Supabase

// MARK: - PushNotificationManager

@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    
    @Published var isAuthorized: Bool = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
    }
    
    // MARK: - 通知許可をリクエスト
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
            
            self.isAuthorized = granted
            
            if granted {
                await registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            print("通知許可エラー: \(error)")
            return false
        }
    }
    
    // MARK: - リモート通知に登録
    func registerForRemoteNotifications() async {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - デバイストークンを保存
    func setDeviceToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        // Supabaseに登録
        Task.detached {
            await Self.registerTokenToSupabaseStatic(tokenString)
        }
    }
    
    // MARK: - Supabaseにトークン登録（static）
    private static func registerTokenToSupabaseStatic(_ token: String) async {
        do {
            try await SupabaseClientManager.shared.client
                .database
                .rpc("register_push_token", params: [
                    "p_device_token": token,
                    "p_platform": "ios"
                ])
                .execute()
            print("プッシュトークン登録成功")
        } catch {
            print("プッシュトークン登録エラー: \(error)")
        }
    }
    
    // MARK: - Supabaseからトークン削除（ログアウト時）
    func removeTokenFromSupabase() async {
        guard let token = deviceToken else { return }
        
        do {
            try await SupabaseClientManager.shared.client
                .database
                .rpc("remove_push_token", params: ["p_device_token": token])
                .execute()
            print("プッシュトークン削除成功")
        } catch {
            print("プッシュトークン削除エラー: \(error)")
        }
    }
    
    // MARK: - 現在の許可状態を確認
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - 通知設定を取得
    func fetchNotificationSettings() async throws -> NotificationSettings {
        let response = try await SupabaseClientManager.shared.client
            .database
            .rpc("get_or_create_notification_settings")
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NotificationSettings.self, from: response.data)
    }
    
    // MARK: - 通知設定を更新
    func updateNotificationSettings(
        pushEnabled: Bool? = nil,
        notifyOnStolen: Bool? = nil,
        notifyOnAttempts: Bool? = nil,
        attemptThreshold: Int? = nil
    ) async throws -> NotificationSettings {
        // パラメータをStringで構築
        var params: [String: String] = [:]
        
        if let pushEnabled = pushEnabled {
            params["p_push_enabled"] = pushEnabled ? "true" : "false"
        }
        if let notifyOnStolen = notifyOnStolen {
            params["p_notify_on_stolen"] = notifyOnStolen ? "true" : "false"
        }
        if let notifyOnAttempts = notifyOnAttempts {
            params["p_notify_on_attempts"] = notifyOnAttempts ? "true" : "false"
        }
        if let attemptThreshold = attemptThreshold {
            params["p_attempt_threshold"] = String(attemptThreshold)
        }
        
        let response = try await SupabaseClientManager.shared.client
            .database
            .rpc("update_notification_settings", params: params)
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NotificationSettings.self, from: response.data)
    }
}
