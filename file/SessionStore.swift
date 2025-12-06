import Foundation
import Combine
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    @Published var isSignedIn: Bool = false

    private var client: SupabaseClient {
        SupabaseClientManager.shared.client
    }

    init() {
        // アプリ起動時に既存セッションの確認
        Task {
            await refreshSessionState()
        }
    }

    func refreshSessionState() async {
        do {
            let session = try await client.auth.session
            isSignedIn = (session != nil)
        } catch {
            // セッション取得に失敗したら未ログイン扱い
            isSignedIn = false
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // ログだけ吐いて無視でもOK
            print("Sign out error: \(error)")
        }
        isSignedIn = false
    }
}
