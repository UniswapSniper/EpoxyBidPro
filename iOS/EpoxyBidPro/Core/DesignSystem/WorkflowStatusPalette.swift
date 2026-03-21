import SwiftUI

enum WorkflowStatusPalette {
    static func bid(_ status: String) -> Color {
        switch status {
        case "DRAFT":    return EBPColor.outline
        case "SENT":     return EBPColor.primary
        case "VIEWED":   return EBPColor.tertiary
        case "SIGNED":   return EBPColor.success
        case "DECLINED": return EBPColor.error
        case "EXPIRED":  return EBPColor.outline
        default:          return EBPColor.onSurfaceVariant
        }
    }

    static func job(_ status: String) -> Color {
        switch status {
        case "SCHEDULED":   return EBPColor.primary
        case "IN_PROGRESS": return EBPColor.secondary
        case "PUNCH_LIST":  return EBPColor.secondary
        case "COMPLETE":    return EBPColor.success
        case "INVOICED":    return EBPColor.tertiary
        case "PAID":        return EBPColor.success
        default:             return EBPColor.onSurfaceVariant
        }
    }

    static func invoice(_ status: String, isOverdue: Bool) -> Color {
        if isOverdue { return EBPColor.error }
        switch status {
        case "DRAFT":   return EBPColor.outline
        case "SENT":    return EBPColor.primary
        case "VIEWED":  return EBPColor.tertiary
        case "PARTIAL": return EBPColor.secondary
        case "PAID":    return EBPColor.success
        case "VOID":    return EBPColor.outline
        default:         return EBPColor.onSurfaceVariant
        }
    }

    static func lead(_ status: String) -> Color {
        switch status {
        case "NEW":        return EBPColor.primary
        case "CONTACTED":  return EBPColor.primaryFixedDim
        case "SITE_VISIT": return EBPColor.secondary
        case "BID_SENT":   return EBPColor.primaryContainer
        case "WON":        return EBPColor.success
        case "LOST":       return EBPColor.error
        default:            return EBPColor.onSurfaceVariant
        }
    }
}
