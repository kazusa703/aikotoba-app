import Foundation
import StoreKit
import Combine

// MARK: - Passcode Length Product Info

struct PasscodeLengthProduct: Sendable {
    let length: Int
    let productId: String
    let price: String
    let combinationCount: String
    
    static let all: [PasscodeLengthProduct] = [
        PasscodeLengthProduct(length: 3, productId: "", price: "無料", combinationCount: "1,000通り"),
        PasscodeLengthProduct(length: 4, productId: "com.aikotoba.passcode.4digit", price: "¥120", combinationCount: "1万通り"),
        PasscodeLengthProduct(length: 5, productId: "com.aikotoba.passcode.5digit", price: "¥250", combinationCount: "10万通り"),
        PasscodeLengthProduct(length: 6, productId: "com.aikotoba.passcode.6digit", price: "¥500", combinationCount: "100万通り"),
        PasscodeLengthProduct(length: 7, productId: "com.aikotoba.passcode.7digit", price: "¥980", combinationCount: "1,000万通り"),
        PasscodeLengthProduct(length: 8, productId: "com.aikotoba.passcode.8digit", price: "¥1,480", combinationCount: "1億通り"),
        PasscodeLengthProduct(length: 9, productId: "com.aikotoba.passcode.9digit", price: "¥1,980", combinationCount: "10億通り"),
        PasscodeLengthProduct(length: 10, productId: "com.aikotoba.passcode.10digit", price: "¥2,980", combinationCount: "100億通り"),
    ]
    
    static func product(for length: Int) -> PasscodeLengthProduct? {
        return all.first { $0.length == length }
    }
    
    static func availableUpgrades(from currentLength: Int) -> [PasscodeLengthProduct] {
        return all.filter { $0.length > currentLength }
    }
}

// MARK: - StoreKit Manager

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        let productIds = PasscodeLengthProduct.all
            .filter { !$0.productId.isEmpty }
            .map { $0.productId }
        
        do {
            products = try await Product.products(for: productIds)
            products.sort { p1, p2 in
                let length1 = extractLength(from: p1.id)
                let length2 = extractLength(from: p2.id)
                return length1 < length2
            }
        } catch {
            print("Failed to load products: \(error)")
            errorMessage = "商品の読み込みに失敗しました"
        }
    }
    
    private func extractLength(from productId: String) -> Int {
        if let match = productId.range(of: #"(\d+)digit"#, options: .regularExpression) {
            let numberStr = productId[match].dropLast(5)
            return Int(numberStr) ?? 0
        }
        return 0
    }
    
    // MARK: - Get Product for Length
    
    func product(for length: Int) -> Product? {
        let productId = "com.aikotoba.passcode.\(length)digit"
        return products.first { $0.id == productId }
    }
    
    // MARK: - Purchase
    
    func purchase(length: Int) async throws -> Bool {
        guard let product = product(for: length) else {
            throw StoreKitError.productNotFound
        }
        
        return try await purchase(product: product)
    }
    
    func purchase(product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            purchasedProductIDs.insert(product.id)
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    // MARK: - Verify Transaction
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Listen for Transactions
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }
    }
    
    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result {
            purchasedProductIDs.insert(transaction.productID)
            await transaction.finish()
        }
    }
    
    // MARK: - Update Purchased Products
    
    func updatePurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProductIDs.insert(transaction.productID)
            }
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            print("Restore failed: \(error)")
            errorMessage = "購入の復元に失敗しました"
        }
    }
    
    // MARK: - Get Display Price
    
    func displayPrice(for length: Int) -> String {
        if length == 3 {
            return "無料"
        }
        
        if let product = product(for: length) {
            return product.displayPrice
        }
        
        return PasscodeLengthProduct.product(for: length)?.price ?? "---"
    }
}

// MARK: - Errors

enum StoreKitError: Error, LocalizedError {
    case productNotFound
    case verificationFailed
    case purchaseFailed
    
    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "商品が見つかりませんでした"
        case .verificationFailed:
            return "購入の検証に失敗しました"
        case .purchaseFailed:
            return "購入に失敗しました"
        }
    }
}
