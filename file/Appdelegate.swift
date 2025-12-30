import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 通知デリゲートを設定
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // MARK: - Remote Notification Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // デバイストークンをマネージャーに渡す
        Task { @MainActor in
            PushNotificationManager.shared.setDeviceToken(deviceToken)
        }
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("プッシュ通知登録失敗: \(error.localizedDescription)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // フォアグラウンドで通知を受信した時
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // フォアグラウンドでもバナー、サウンド、バッジを表示
        completionHandler([.banner, .sound, .badge])
    }
    
    // 通知をタップした時
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // 通知データを処理（必要に応じて画面遷移など）
        handleNotification(userInfo: userInfo)
        
        completionHandler()
    }
    
    private func handleNotification(userInfo: [AnyHashable: Any]) {
        // 通知の種類に応じて処理
        if let type = userInfo["type"] as? String {
            print("通知タイプ: \(type)")
            // 必要に応じてNotificationCenterで画面遷移を通知
        }
    }
}
