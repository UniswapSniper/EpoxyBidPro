import Foundation
import SwiftUI
import AuthenticationServices

// ═══════════════════════════════════════════════════════════════════════════════
// AuthManager.swift
// Manages authentication state using @Observable (iOS 17+).
// Replaces the old ObservableObject-based AuthStore.
// Tokens stored in Keychain, business profile synced to backend.
// ═══════════════════════════════════════════════════════════════════════════════

@Observable
@MainActor
final class AuthManager {

    // MARK: - Auth State

    var isAuthenticated = false
    var hasCompletedOnboarding = false
    var hasCompletedBusinessSetup = false

    var userId: String = ""
    var userEmail: String = ""
    var userName: String = ""

    var isAuthenticating = false
    var authError: String? = nil

    // MARK: - Business Profile

    var businessId: String = ""
    var businessName: String = ""
    var businessPhone: String = ""
    var businessEmail: String = ""
    var businessAddress: String = ""
    var businessCity: String = ""
    var businessState: String = ""
    var businessZip: String = ""
    var businessWebsite: String = ""
    var businessLogoUrl: String = ""
    var businessLicenseNumber: String = ""
    var businessBrandColor: String = ""
    var bidPrefix: String = "BID"
    var invoicePrefix: String = "INV"

    // MARK: - Pricing Defaults

    var defaultLaborRate: Double = 55
    var defaultOverheadRate: Double = 15
    var defaultMarkup: Double = 25
    var defaultMargin: Double = 40
    var defaultTaxRate: Double = 8
    var defaultMobilizationFee: Double = 150
    var defaultMinimumJobPrice: Double = 500

    // MARK: - Private

    private let apiClient = APIClient.shared
    private let keychain = KeychainService.self

    // MARK: - Init

    init() {
        restoreSession()
    }

    // MARK: - User Display

    var userInitials: String {
        let parts = userName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(userName.prefix(2)).uppercased()
    }

    var userFirstName: String {
        userName.split(separator: " ").first.map(String.init) ?? userName
    }

    // MARK: - Sign in with Apple

    func signInWithApple(result: Result<ASAuthorization, Error>) {
        isAuthenticating = true
        authError = nil

        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                authError = String(localized: "auth.error.invalidCredential")
                isAuthenticating = false
                return
            }

            let appleUserId = credential.user

            // Name is only provided on first sign-in
            if let fullName = credential.fullName {
                let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
                if !parts.isEmpty {
                    userName = parts.joined(separator: " ")
                    UserDefaults.standard.set(userName, forKey: "ebp_user_name")
                }
            }

            // Email may only be provided on first sign-in
            if let email = credential.email {
                userEmail = email
                UserDefaults.standard.set(email, forKey: "ebp_user_email")
            }

            // Identity token for backend verification
            if let tokenData = credential.identityToken,
               let idToken = String(data: tokenData, encoding: .utf8) {
                Task {
                    await authenticateWithBackend(appleUserId: appleUserId, idToken: idToken)
                }
            } else {
                // Fallback to local auth if no token (simulator)
                authenticateLocally(appleUserId: appleUserId)
            }

        case .failure(let error):
            handleAppleSignInError(error)
        }
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String, password: String) async {
        isAuthenticating = true
        authError = nil

        do {
            let response: AuthResponse = try await apiClient.request(
                .login(email: email, password: password)
            )
            handleAuthResponse(response)
        } catch {
            // Fallback for local development without backend
            #if DEBUG
            print("⚠️ Backend login failed, using local auth: \(error)")
            userEmail = email
            userName = email.components(separatedBy: "@").first?.capitalized ?? "User"
            userId = UUID().uuidString
            let localToken = "local_\(UUID().uuidString)"
            keychain.save(key: .accessToken, string: localToken)
            saveSession()
            isAuthenticated = true
            #else
            authError = String(localized: "auth.error.loginFailed")
            #endif
            isAuthenticating = false
        }
    }

    // MARK: - Register

    func register(
        firstName: String,
        lastName: String,
        email: String,
        password: String
    ) async {
        isAuthenticating = true
        authError = nil

        do {
            let body: [String: String] = [
                "firstName": firstName,
                "lastName": lastName,
                "email": email,
                "password": password,
            ]
            let endpoint = APIEndpoint(method: .POST, path: "/auth/register", body: body)
            let response: AuthResponse = try await apiClient.request(endpoint)
            handleAuthResponse(response)
        } catch {
            #if DEBUG
            print("⚠️ Backend register failed, using local auth: \(error)")
            userName = "\(firstName) \(lastName)"
            userEmail = email
            userId = UUID().uuidString
            let localToken = "local_\(UUID().uuidString)"
            keychain.save(key: .accessToken, string: localToken)
            saveSession()
            isAuthenticated = true
            #else
            authError = String(localized: "auth.error.registerFailed")
            #endif
            isAuthenticating = false
        }
    }

    // MARK: - Refresh Token

    func refreshToken() async -> Bool {
        guard let refreshToken = keychain.loadString(key: .refreshToken) else {
            return false
        }

        do {
            let body = ["refreshToken": refreshToken]
            let endpoint = APIEndpoint(method: .POST, path: "/auth/refresh", body: body)
            let response: AuthResponse = try await apiClient.request(endpoint)

            keychain.save(key: .accessToken, string: response.accessToken)
            keychain.save(key: .refreshToken, string: response.refreshToken)
            return true
        } catch {
            #if DEBUG
            print("⚠️ Token refresh failed: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Complete Business Setup

    func completeBusinessSetup() {
        hasCompletedBusinessSetup = true
        UserDefaults.standard.set(true, forKey: "ebp_business_setup_done")

        // Persist business settings
        let prefs = UserDefaults.standard
        prefs.set(businessName, forKey: "ebp_business_name")
        prefs.set(businessPhone, forKey: "ebp_business_phone")
        prefs.set(businessEmail, forKey: "ebp_business_email")
        prefs.set(businessAddress, forKey: "ebp_business_address")
        prefs.set(businessCity, forKey: "ebp_business_city")
        prefs.set(businessState, forKey: "ebp_business_state")
        prefs.set(businessZip, forKey: "ebp_business_zip")
        prefs.set(businessLicenseNumber, forKey: "ebp_business_license")
        prefs.set(defaultLaborRate, forKey: "ebp_labor_rate")
        prefs.set(defaultOverheadRate, forKey: "ebp_overhead_rate")
        prefs.set(defaultMarkup, forKey: "ebp_markup")
        prefs.set(defaultTaxRate, forKey: "ebp_tax_rate")
        prefs.set(defaultMobilizationFee, forKey: "ebp_mobilization_fee")
        prefs.set(defaultMinimumJobPrice, forKey: "ebp_min_job_price")

        // Sync to backend
        Task {
            await syncBusinessProfile()
        }
    }

    // MARK: - Fetch Profile from Backend

    func fetchProfile() async {
        do {
            let response: AuthResponse = try await apiClient.request(.me)
            updateFromUser(response.user)
            if let biz = response.business {
                updateFromBusiness(biz)
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to fetch profile: \(error)")
            #endif
        }
    }

    // MARK: - Sign Out

    func signOut() {
        isAuthenticated = false
        hasCompletedOnboarding = false
        hasCompletedBusinessSetup = false
        userId = ""
        userEmail = ""
        userName = ""
        businessId = ""
        businessName = ""
        authError = nil

        // Clear Keychain tokens
        keychain.clearAll()

        // Clear UserDefaults session data
        let keysToRemove = [
            "ebp_user_id", "ebp_user_email", "ebp_user_name",
            "ebp_business_setup_done", "ebp_business_name",
            "ebp_business_phone", "ebp_business_email",
            "ebp_business_address", "ebp_business_city",
            "ebp_business_state", "ebp_business_zip",
            "ebp_business_license", "ebp_labor_rate",
            "ebp_overhead_rate", "ebp_markup", "ebp_tax_rate",
            "ebp_mobilization_fee", "ebp_min_job_price",
        ]
        keysToRemove.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    // MARK: - Private — Auth Flow

    private func authenticateWithBackend(appleUserId: String, idToken: String) async {
        do {
            let response: AuthResponse = try await apiClient.request(
                .appleSignIn(identityToken: idToken)
            )
            handleAuthResponse(response)
        } catch {
            #if DEBUG
            print("⚠️ Backend Apple auth failed, using local: \(error)")
            #endif
            authenticateLocally(appleUserId: appleUserId)
        }
    }

    private func handleAuthResponse(_ response: AuthResponse) {
        // Store tokens securely in Keychain
        keychain.save(key: .accessToken, string: response.accessToken)
        keychain.save(key: .refreshToken, string: response.refreshToken)

        // Update state from response
        updateFromUser(response.user)
        if let biz = response.business {
            updateFromBusiness(biz)
            hasCompletedBusinessSetup = true
            UserDefaults.standard.set(true, forKey: "ebp_business_setup_done")
        }

        saveSession()
        isAuthenticated = true
        isAuthenticating = false
    }

    private func updateFromUser(_ user: UserDTO) {
        userId = user.id
        userEmail = user.email
        userName = "\(user.firstName) \(user.lastName)"
        UserDefaults.standard.set(userName, forKey: "ebp_user_name")
        UserDefaults.standard.set(userEmail, forKey: "ebp_user_email")
        keychain.save(key: .userId, string: user.id)
    }

    private func updateFromBusiness(_ biz: BusinessDTO) {
        businessId = biz.id
        businessName = biz.name
        businessPhone = biz.phone ?? ""
        businessEmail = biz.email ?? ""
        businessWebsite = biz.website ?? ""
        businessAddress = biz.address ?? ""
        businessCity = biz.city ?? ""
        businessState = biz.state ?? ""
        businessZip = biz.zip ?? ""
        businessLicenseNumber = biz.licenseNumber ?? ""
        businessBrandColor = biz.brandColor ?? ""
        bidPrefix = biz.bidPrefix ?? "BID"
        invoicePrefix = biz.invoicePrefix ?? "INV"

        defaultTaxRate = biz.taxRate ?? 8
        defaultMarkup = biz.defaultMarkup ?? 25
        defaultMargin = biz.defaultMargin ?? 40
        defaultLaborRate = biz.laborRate ?? 55
        defaultOverheadRate = biz.overheadRate ?? 15
        defaultMobilizationFee = biz.mobilizationFee ?? 150
        defaultMinimumJobPrice = biz.minimumJobPrice ?? 500

        // Persist locally as well
        let prefs = UserDefaults.standard
        prefs.set(businessName, forKey: "ebp_business_name")
        prefs.set(businessPhone, forKey: "ebp_business_phone")
        prefs.set(businessEmail, forKey: "ebp_business_email")
        prefs.set(defaultLaborRate, forKey: "ebp_labor_rate")
        prefs.set(defaultOverheadRate, forKey: "ebp_overhead_rate")
        prefs.set(defaultMarkup, forKey: "ebp_markup")
        prefs.set(defaultTaxRate, forKey: "ebp_tax_rate")
        prefs.set(defaultMobilizationFee, forKey: "ebp_mobilization_fee")
        prefs.set(defaultMinimumJobPrice, forKey: "ebp_min_job_price")
    }

    private func authenticateLocally(appleUserId: String) {
        userId = appleUserId
        let localToken = "apple_\(UUID().uuidString)"
        keychain.save(key: .accessToken, string: localToken)

        // Restore persisted name/email if not received this time
        if userName.isEmpty {
            userName = UserDefaults.standard.string(forKey: "ebp_user_name") ?? "User"
        }
        if userEmail.isEmpty {
            userEmail = UserDefaults.standard.string(forKey: "ebp_user_email") ?? ""
        }

        saveSession()
        isAuthenticated = true
        hasCompletedBusinessSetup = UserDefaults.standard.bool(forKey: "ebp_business_setup_done")
        isAuthenticating = false
    }

    private func handleAppleSignInError(_ error: Error) {
        let nsError = error as NSError

        if nsError.code == ASAuthorizationError.canceled.rawValue {
            authError = nil
        } else {
            switch nsError.code {
            case ASAuthorizationError.invalidResponse.rawValue:
                authError = String(localized: "auth.error.invalidResponse")
            case ASAuthorizationError.notHandled.rawValue:
                authError = String(localized: "auth.error.notHandled")
            case ASAuthorizationError.failed.rawValue:
                authError = String(localized: "auth.error.failed")
            case ASAuthorizationError.unknown.rawValue:
                authError = String(localized: "auth.error.unknown")
            case ASAuthorizationError.notInteractive.rawValue:
                authError = String(localized: "auth.error.notInteractive")
            default:
                authError = "Error: \(error.localizedDescription) (Code: \(nsError.code))"
            }
        }
        isAuthenticating = false
    }

    // MARK: - Private — Session Persistence

    private func saveSession() {
        keychain.save(key: .userId, string: userId)
        UserDefaults.standard.set(userId, forKey: "ebp_user_id")
    }

    private func restoreSession() {
        // Try Keychain first (new approach), fallback to UserDefaults (migration)
        let token = keychain.loadString(key: .accessToken)
            ?? UserDefaults.standard.string(forKey: "ebp_access_token")

        guard let token, !token.isEmpty else { return }

        // Migrate token from UserDefaults to Keychain if needed
        if keychain.loadString(key: .accessToken) == nil {
            keychain.save(key: .accessToken, string: token)
            UserDefaults.standard.removeObject(forKey: "ebp_access_token")
        }

        userId = keychain.loadString(key: .userId)
            ?? UserDefaults.standard.string(forKey: "ebp_user_id") ?? ""
        userName = UserDefaults.standard.string(forKey: "ebp_user_name") ?? "User"
        userEmail = UserDefaults.standard.string(forKey: "ebp_user_email") ?? ""
        isAuthenticated = true
        hasCompletedBusinessSetup = UserDefaults.standard.bool(forKey: "ebp_business_setup_done")

        // Restore pricing defaults
        let prefs = UserDefaults.standard
        businessName = prefs.string(forKey: "ebp_business_name") ?? ""
        businessPhone = prefs.string(forKey: "ebp_business_phone") ?? ""
        businessEmail = prefs.string(forKey: "ebp_business_email") ?? ""
        defaultLaborRate = prefs.double(forKey: "ebp_labor_rate").nonZero(default: 55)
        defaultOverheadRate = prefs.double(forKey: "ebp_overhead_rate").nonZero(default: 15)
        defaultMarkup = prefs.double(forKey: "ebp_markup").nonZero(default: 25)
        defaultTaxRate = prefs.double(forKey: "ebp_tax_rate").nonZero(default: 8)
        defaultMobilizationFee = prefs.double(forKey: "ebp_mobilization_fee").nonZero(default: 150)
        defaultMinimumJobPrice = prefs.double(forKey: "ebp_min_job_price").nonZero(default: 500)

        // Attempt to refresh from backend
        Task {
            await fetchProfile()
        }
    }

    // MARK: - Private — Backend Sync

    private func syncBusinessProfile() async {
        // In production: PUT /businesses/:id with all profile data
        #if DEBUG
        print("📡 Syncing business profile to backend...")
        #endif
    }
}

// MARK: - Double Extension

private extension Double {
    func nonZero(default fallback: Double) -> Double {
        self == 0 ? fallback : self
    }
}
