import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var locale: Locale? {
        if self == .system { return nil } // Use system locale
        return Locale(identifier: rawValue)
    }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .system:
            return "language.system"
        case .english:
            return "language.english"
        case .spanish:
            return "language.spanish"
        }
    }

    var shortCode: String {
        rawValue.uppercased()
    }

    /// Detects the system's preferred language if it's English or Spanish.
    /// Defaults to English if neither is preferred.
    static var systemLanguage: AppLanguage {
        // Preferred languages gives the order the user prefers.
        // We look for the first one that starts with 'en' or 'es'.
        if let preferred = Locale.preferredLanguages.first?.lowercased() {
            if preferred.hasPrefix("es") { return .spanish }
            if preferred.hasPrefix("en") { return .english }
        }
        return .english // Fallback
    }
}
