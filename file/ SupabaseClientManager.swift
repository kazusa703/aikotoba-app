import Foundation
import Supabase

final class SupabaseClientManager {
    static let shared = SupabaseClientManager()
    
    let client: SupabaseClient
    
    private init() {
            // ★注意: ここは手入力で修正することをお勧めします
            // IDが "ryj" なら修正してください
        // ↓ コピペ禁止！手で打ってください
        let supabaseUrl = URL(string: "https://mdlhncrhfluikvnixryi.supabase.co")!
            
            // ★注意: Settings > API から "anon public" キー（eyJから始まるもの）をコピペしてください
            let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kbG..."

            self.client = SupabaseClient(
                supabaseURL: supabaseUrl,
                supabaseKey: supabaseKey,
                options: SupabaseClientOptions(
                    auth: SupabaseClientOptions.AuthOptions(
                        flowType: .pkce,
                        emitLocalSessionAsInitialSession: true
                    )
                )
            )
        }
    }


