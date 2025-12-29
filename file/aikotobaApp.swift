import SwiftUI
import Supabase  // ← 追加

@main
struct AikotobaApp: App {
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
