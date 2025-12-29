import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

final class AuthService: NSObject {
    static let shared = AuthService()

    private var client: SupabaseClient {
        SupabaseClientManager.shared.client
    }
    
    // Apple Sign-In用
    private var currentNonce: String?
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?

    private override init() {
        super.init()
    }

    // MARK: - Email/Password Auth
    
    func signUp(email: String, password: String) async throws {
        _ = try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func currentUserId() -> UUID? {
        client.auth.currentUser?.id
    }
    
    // MARK: - Apple Sign-In
    
    @MainActor
    func signInWithApple() async throws {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.appleSignInContinuation = continuation
            authorizationController.performRequests()
        }
    }
    
    // MARK: - Google Sign-In
    
    @MainActor
    func signInWithGoogle() async throws {
        // Supabase OAuth flow
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "aikotoba://auth-callback")
        )
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let nonce = currentNonce else {
            appleSignInContinuation?.resume(throwing: AuthError.invalidCredential)
            appleSignInContinuation = nil
            return
        }
        
        Task {
            do {
                _ = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: identityToken,
                        nonce: nonce
                    )
                )
                appleSignInContinuation?.resume()
            } catch {
                appleSignInContinuation?.resume(throwing: error)
            }
            appleSignInContinuation = nil
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleSignInContinuation?.resume(throwing: error)
        appleSignInContinuation = nil
    }
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case invalidCredential
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "認証情報が無効です"
        case .cancelled:
            return "キャンセルされました"
        }
    }
}
