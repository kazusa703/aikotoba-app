import Foundation
import Supabase

final class AuthService {
    static let shared = AuthService()

    private var client: SupabaseClient {
        SupabaseClientManager.shared.client
    }

    private init() {}

    // サインアップ（メール＋パスワード）
    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    // サインイン
    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    // サインアウト
    func signOut() async throws {
        try await client.auth.signOut()
    }

    // 現在のユーザーID
    func currentUserId() -> UUID? {
        client.auth.currentUser?.id
    }
}
