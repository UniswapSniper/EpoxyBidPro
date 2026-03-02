import UIKit

enum AppHaptics {
    enum Pattern {
        case light
        case medium
        case heavy
        case soft
        case rigid
        case success
        case warning
        case error
    }

    static func trigger(_ pattern: Pattern, compact: Bool = false) {
        let effective = map(pattern: pattern, compact: compact)

        switch effective {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private static func map(pattern: Pattern, compact: Bool) -> Pattern {
        let subtleMode = UserDefaults.standard.string(forKey: "dockHapticMode") == "subtle"

        if subtleMode {
            switch pattern {
            case .success, .warning, .error, .heavy, .medium, .rigid, .soft:
                return .light
            case .light:
                return .light
            }
        }

        if compact {
            switch pattern {
            case .heavy: return .medium
            case .medium, .rigid, .soft, .success, .warning, .error: return .light
            case .light: return .light
            }
        }

        return pattern
    }
}
