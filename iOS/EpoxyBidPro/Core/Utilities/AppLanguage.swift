import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .english:
            return "language.english"
        case .spanish:
            return "language.spanish"
        }
    }

    var shortCode: String {
        rawValue.uppercased()
    }
}
