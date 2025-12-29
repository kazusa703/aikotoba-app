import Foundation
import Supabase

final class SupabaseClientManager {
    static let shared = SupabaseClientManager()
    
    let client: SupabaseClient
    
    private init() {
        let supabaseUrl = URL(string: "https://mdlhncrhfluikvnixryi.supabase.co")!
        
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kbGhuY3JoZmx1aWt2bml4cnlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ4MDYwNDAsImV4cCI6MjA4MDM4MjA0MH0.WWLY3vDvtCQRpKryT5LLjMWe_-irjKJX9NSgnzwt2js"

        self.client = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    redirectToURL: URL(string: "aikotoba://auth-callback"),  // ← 先に書く
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
