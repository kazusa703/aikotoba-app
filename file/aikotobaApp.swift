import SwiftUI
import Supabase

@main
struct AikotobaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if sessionStore.isSignedIn || sessionStore.isGuestMode {
                    RootView()
                } else {
                    AuthView()
                }
            }
            .environmentObject(sessionStore)
            .onOpenURL { url in
                Task {
                    await handleOpenURL(url)
                }
            }
            .task {
                // ログイン時にプッシュ通知の許可状態を確認
                if sessionStore.isSignedIn {
                    await PushNotificationManager.shared.checkAuthorizationStatus()
                }
            }
        }
    }
    
    private func handleOpenURL(_ url: URL) async {
        do {
            try await SupabaseClientManager.shared.client.auth.session(from: url)
            await sessionStore.refreshSessionState()
        } catch {
            print("Auth callback error: \(error)")
        }
    }
}
