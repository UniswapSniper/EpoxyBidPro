import StoreKit
import SwiftUI

// ─── SubscriptionManager ──────────────────────────────────────────────────────
// StoreKit 2 subscription service.
// Inject as @EnvironmentObject from the app root.

@MainActor
final class SubscriptionManager: ObservableObject {

    // MARK: - Product IDs
    // These must match exactly what you configure in App Store Connect.

    enum ProductID {
        static let soloMonthly  = "com.epoxyBidPro.app.solo.monthly"
        static let soloAnnual   = "com.epoxyBidPro.app.solo.annual"
        static let proMonthly   = "com.epoxyBidPro.app.pro.monthly"
        static let proAnnual    = "com.epoxyBidPro.app.pro.annual"
        static let teamMonthly  = "com.epoxyBidPro.app.team.monthly"
        static let teamAnnual   = "com.epoxyBidPro.app.team.annual"

        static let all: Set<String> = [
            soloMonthly, soloAnnual,
            proMonthly,  proAnnual,
            teamMonthly, teamAnnual,
        ]
    }

    // MARK: - Published State

    @Published var products: [Product] = []
    @Published var currentTier: SubscriptionTier = .none
    @Published var isLoading = false
    @Published var purchaseError: String? = nil
    @Published var showPaywall = false

    // MARK: - Private

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Init

    init() {
        updateListenerTask = startTransactionListener()
        Task {
            await loadProducts()
            await refreshStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: ProductID.all)
            // Sort: monthly before annual, solo < pro < team
            products = loaded.sorted { lhs, rhs in
                let lTier = SubscriptionTier(productID: lhs.productID)?.rawValue ?? 0
                let rTier = SubscriptionTier(productID: rhs.productID)?.rawValue ?? 0
                if lTier != rTier { return lTier < rTier }
                return lhs.price < rhs.price
            }
        } catch {
            print("[SubscriptionManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await refreshStatus()
                await transaction.finish()
                showPaywall = false
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch StoreError.failedVerification {
            purchaseError = "Purchase verification failed. Please contact support."
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshStatus()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Status

    func refreshStatus() async {
        var highest: SubscriptionTier = .none
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            guard tx.revocationDate == nil else { continue }
            if let tier = SubscriptionTier(productID: tx.productID), tier > highest {
                highest = tier
            }
        }
        currentTier = highest
    }

    // MARK: - Convenience

    /// Products belonging to a given tier (monthly first, then annual).
    func products(for tier: SubscriptionTier) -> [Product] {
        products.filter { SubscriptionTier(productID: $0.productID) == tier }
    }

    /// Monthly product for a tier (nil if not loaded yet).
    func monthlyProduct(for tier: SubscriptionTier) -> Product? {
        products.first { product in
            SubscriptionTier(productID: product.productID) == tier &&
            product.productID.hasSuffix(".monthly")
        }
    }

    /// Annual product for a tier (nil if not loaded yet).
    func annualProduct(for tier: SubscriptionTier) -> Product? {
        products.first { product in
            SubscriptionTier(productID: product.productID) == tier &&
            product.productID.hasSuffix(".annual")
        }
    }

    /// Returns true if the user has access to the requested feature tier.
    func isEntitled(to requiredTier: SubscriptionTier) -> Bool {
        currentTier >= requiredTier
    }

    // MARK: - Transaction Listener

    private func startTransactionListener() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await self?.refreshStatus()
                await transaction.finish()
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    // MARK: - Errors

    enum StoreError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "Transaction verification failed." }
    }
}
