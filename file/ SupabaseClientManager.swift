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
            let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kbGhuY3JoZmx1aWt2bml4cnlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4MDYwNDAsImV4cCI6MjA4MDM4MjA0MH0.WWLY3vDvtCQRpKryT5LLjMWe_-irjKJX9NSgnzwt2js"

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


