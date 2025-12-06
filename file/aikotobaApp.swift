import SwiftUI

@main
struct AikotobaApp: App {
    @StateObject private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if sessionStore.isSignedIn {
                    RootView()
                } else {
                    AuthView()
                }
            }
            .environmentObject(sessionStore)
        }
    }
}
