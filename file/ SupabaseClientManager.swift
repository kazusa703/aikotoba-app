import Foundation
import Supabase

final class SupabaseClientManager {
    static let shared = SupabaseClientManager()
    
    let client: SupabaseClient
    
    private init() {
        // URLの末尾は正しい "ryj" です
        let supabaseUrl = URL(string: "https://mdlhncrhfluikvnixryi.supabase.co")!
        let supabaseKey = "sb_publishable_gMGC4z-W3stM-7Ub4d0XLA_URbDjb1j"
        
        self.client = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    // モバイルアプリ向けの推奨フロー
                    flowType: .pkce,
                    // ↓ これを追加すると警告が消えます（新しい挙動を今のうちに有効化する設定）
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
