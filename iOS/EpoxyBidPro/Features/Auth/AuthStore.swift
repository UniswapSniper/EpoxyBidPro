import Foundation
import SwiftUI
import AuthenticationServices
import SwiftData

// ─── AuthStore ────────────────────────────────────────────────────────────────
// Manages authentication state with Sign in with Apple.
// Persists session to Keychain. Handles business profile setup flow.

@MainActor
final class AuthStore: ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticated = false
    @Published var hasCompletedOnboarding = false
    @Published var hasCompletedBusinessSetup = false

    @Published var userId: String = ""
    @Published var userEmail: String = ""
    @Published var userName: String = ""
    @Published var accessToken: String = ""

    @Published var isAuthenticating = false
    @Published var authError: String? = nil

    // MARK: - Business Profile

    @Published var businessName: String = ""
    @Published var businessPhone: String = ""
    @Published var businessEmail: String = ""
    @Published var businessAddress: String = ""
    @Published var businessCity: String = ""
    @Published var businessState: String = ""
    @Published var businessZip: String = ""
    @Published var businessLogoUrl: String = ""
    @Published var businessLicenseNumber: String = ""

    // Pricing Defaults
    @Published var defaultLaborRate: Double = 55
    @Published var defaultOverheadRate: Double = 15
    @Published var defaultMarkup: Double = 25
    @Published var defaultTaxRate: Double = 8
    @Published var defaultMobilizationFee: Double = 150
    @Published var defaultMinimumJobPrice: Double = 500

    // MARK: - Init

    init() {
        restoreSession()
    }

    // MARK: - Sign in with Apple

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        isAuthenticating = true
        authError = nil
        
        #if DEBUG
        print("🍎 Sign in with Apple: Processing result...")
        #endif

        switch result {
        case .success(let auth):
            #if DEBUG
            print("🍎 Sign in with Apple: Authorization succeeded")
            #endif
            
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Invalid credential type"
                isAuthenticating = false
                #if DEBUG
                print("🍎 Sign in with Apple: ❌ Invalid credential type")
                #endif
                return
            }

            let appleUserId = credential.user
            #if DEBUG
            print("🍎 Sign in with Apple: User ID: \(appleUserId)")
            #endif

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
                // In production: POST to /auth/apple with idToken
                // For now, store locally and authenticate
                authenticateLocally(appleUserId: appleUserId, idToken: idToken)
            } else {
                authenticateLocally(appleUserId: appleUserId, idToken: nil)
            }

        case .failure(let error):
            let nsError = error as NSError
            
            #if DEBUG
            print("🍎 Sign in with Apple: ❌ Error occurred")
            print("   Domain: \(nsError.domain)")
            print("   Code: \(nsError.code)")
            print("   Description: \(nsError.localizedDescription)")
            #endif
            
            if nsError.code == ASAuthorizationError.canceled.rawValue {
                // User canceled — not an error
                authError = nil
                #if DEBUG
                print("🍎 Sign in with Apple: User canceled")
                #endif
            } else {
                // Provide more detailed error messages
                switch nsError.code {
                case ASAuthorizationError.invalidResponse.rawValue:
                    authError = "Invalid response from Apple. Please try again."
                case ASAuthorizationError.notHandled.rawValue:
                    authError = "Request not handled. Please try again."
                case ASAuthorizationError.failed.rawValue:
                    authError = "Authorization failed. Check your Apple ID settings and ensure Sign in with Apple capability is enabled in Xcode."
                case ASAuthorizationError.unknown.rawValue:
                    authError = "Unknown error occurred. Please try again."
                case ASAuthorizationError.notInteractive.rawValue:
                    authError = "Cannot show sign in UI. Please try again."
                default:
                    authError = "Error: \(error.localizedDescription) (Code: \(nsError.code))"
                }
                
                #if DEBUG
                print("🍎 Sign in with Apple: Error message set to: \(authError ?? "nil")")
                #endif
            }
            isAuthenticating = false
        }
    }

    // MARK: - Email Sign In (placeholder for Firebase/email flow)

    func signInWithEmail(email: String, password: String) async {
        isAuthenticating = true
        authError = nil

        // Simulated delay
        try? await Task.sleep(nanoseconds: 800_000_000)

        // In production: POST /auth/login { email, password }
        userEmail = email
        userName = email.components(separatedBy: "@").first?.capitalized ?? "User"
        userId = UUID().uuidString
        accessToken = "local_\(UUID().uuidString)"

        saveSession()
        isAuthenticated = true
        isAuthenticating = false
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

        // In production: PUT /businesses/:id with all profile data
    }

    // MARK: - Sign Out

    func signOut() {
        isAuthenticated = false
        hasCompletedOnboarding = false
        hasCompletedBusinessSetup = false
        userId = ""
        userEmail = ""
        userName = ""
        accessToken = ""

        UserDefaults.standard.removeObject(forKey: "ebp_access_token")
        UserDefaults.standard.removeObject(forKey: "ebp_user_id")
        UserDefaults.standard.removeObject(forKey: "ebp_user_email")
        UserDefaults.standard.removeObject(forKey: "ebp_user_name")
        UserDefaults.standard.removeObject(forKey: "ebp_business_setup_done")
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    // MARK: - Private

    private func authenticateLocally(appleUserId: String, idToken: String?) {
        userId = appleUserId
        accessToken = idToken ?? "apple_\(UUID().uuidString)"

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

    private func saveSession() {
        UserDefaults.standard.set(accessToken, forKey: "ebp_access_token")
        UserDefaults.standard.set(userId, forKey: "ebp_user_id")
    }

    private func restoreSession() {
        if let token = UserDefaults.standard.string(forKey: "ebp_access_token"), !token.isEmpty {
            accessToken = token
            userId = UserDefaults.standard.string(forKey: "ebp_user_id") ?? ""
            userName = UserDefaults.standard.string(forKey: "ebp_user_name") ?? "User"
            userEmail = UserDefaults.standard.string(forKey: "ebp_user_email") ?? ""
            isAuthenticated = true
            hasCompletedBusinessSetup = UserDefaults.standard.bool(forKey: "ebp_business_setup_done")

            // Restore pricing defaults
            let prefs = UserDefaults.standard
            businessName = prefs.string(forKey: "ebp_business_name") ?? ""
            businessPhone = prefs.string(forKey: "ebp_business_phone") ?? ""
            businessEmail = prefs.string(forKey: "ebp_business_email") ?? ""
            defaultLaborRate = prefs.double(forKey: "ebp_labor_rate")
            if defaultLaborRate == 0 { defaultLaborRate = 55 }
            defaultOverheadRate = prefs.double(forKey: "ebp_overhead_rate")
            if defaultOverheadRate == 0 { defaultOverheadRate = 15 }
            defaultMarkup = prefs.double(forKey: "ebp_markup")
            if defaultMarkup == 0 { defaultMarkup = 25 }
            defaultTaxRate = prefs.double(forKey: "ebp_tax_rate")
            if defaultTaxRate == 0 { defaultTaxRate = 8 }
            defaultMobilizationFee = prefs.double(forKey: "ebp_mobilization_fee")
            if defaultMobilizationFee == 0 { defaultMobilizationFee = 150 }
            defaultMinimumJobPrice = prefs.double(forKey: "ebp_min_job_price")
            if defaultMinimumJobPrice == 0 { defaultMinimumJobPrice = 500 }
        }
    }
}
