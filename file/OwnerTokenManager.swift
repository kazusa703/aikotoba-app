import Foundation

final class OwnerTokenManager {
    static let shared = OwnerTokenManager()

    private let key = "deviceOwnerToken"

    private init() {}

    func getOrCreateToken() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key) {
            return existing
        } else {
            let newToken = UUID().uuidString
            defaults.set(newToken, forKey: key)
            return newToken
        }
    }
}
