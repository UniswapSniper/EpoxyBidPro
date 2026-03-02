import SwiftUI

enum WorkflowStatusPalette {
    static func bid(_ status: String) -> Color {
        switch status {
        case "DRAFT":    return Color(.systemGray3)
        case "SENT":     return .blue
        case "VIEWED":   return EBPColor.warning
        case "SIGNED":   return EBPColor.success
        case "DECLINED": return EBPColor.danger
        case "EXPIRED":  return Color(.systemGray4)
        default:          return EBPColor.primary
        }
    }

    static func job(_ status: String) -> Color {
        switch status {
        case "SCHEDULED":   return .blue
        case "IN_PROGRESS": return EBPColor.accent
        case "PUNCH_LIST":  return EBPColor.warning
        case "COMPLETE":    return EBPColor.success
        case "INVOICED":    return .purple
        case "PAID":        return .mint
        default:             return .secondary
        }
    }

    static func invoice(_ status: String, isOverdue: Bool) -> Color {
        if isOverdue { return EBPColor.danger }
        switch status {
        case "DRAFT":   return .secondary
        case "SENT":    return .blue
        case "VIEWED":  return .indigo
        case "PARTIAL": return EBPColor.warning
        case "PAID":    return EBPColor.success
        case "VOID":    return .gray
        default:         return .secondary
        }
    }

    static func lead(_ status: String) -> Color {
        switch status {
        case "NEW":       return .blue
        case "CONTACTED": return .indigo
        case "SITE_VISIT": return EBPColor.warning
        case "BID_SENT":  return EBPColor.accent
        case "WON":       return EBPColor.success
        case "LOST":      return EBPColor.danger
        default:           return .secondary
        }
    }
}
