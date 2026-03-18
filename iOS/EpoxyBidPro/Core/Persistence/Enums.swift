import SwiftUI

// ═══════════════════════════════════════════════════════════════════════════════
// Enums.swift
// Typed domain enums replacing raw String values throughout the app.
// Every enum is Codable (for API DTOs), has a String rawValue (for SwiftData
// storage and backend compatibility), and includes display helpers.
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Lead

enum LeadStatus: String, Codable, CaseIterable, Identifiable {
    case new        = "NEW"
    case contacted  = "CONTACTED"
    case siteVisit  = "SITE_VISIT"
    case bidSent    = "BID_SENT"
    case won        = "WON"
    case lost       = "LOST"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new:       return String(localized: "New")
        case .contacted: return String(localized: "Contacted")
        case .siteVisit: return String(localized: "Site Visit")
        case .bidSent:   return String(localized: "Bid Sent")
        case .won:       return String(localized: "Won")
        case .lost:      return String(localized: "Lost")
        }
    }

    var color: Color {
        switch self {
        case .new:       return .blue
        case .contacted: return .indigo
        case .siteVisit: return EBPColor.warning
        case .bidSent:   return EBPColor.accent
        case .won:       return EBPColor.success
        case .lost:      return EBPColor.danger
        }
    }

    var icon: String {
        switch self {
        case .new:       return "sparkles"
        case .contacted: return "phone.fill"
        case .siteVisit: return "mappin.and.ellipse"
        case .bidSent:   return "paperplane.fill"
        case .won:       return "trophy.fill"
        case .lost:      return "xmark.circle.fill"
        }
    }

    /// Whether this lead is still actionable (not terminal).
    var isActive: Bool { self != .won && self != .lost }
}

enum LeadSource: String, Codable, CaseIterable, Identifiable {
    case referral   = "REFERRAL"
    case google     = "GOOGLE"
    case yelp       = "YELP"
    case facebook   = "FACEBOOK"
    case instagram  = "INSTAGRAM"
    case doorHanger = "DOOR_HANGER"
    case tradeShow  = "TRADE_SHOW"
    case other      = "OTHER"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .referral:   return String(localized: "Referral")
        case .google:     return String(localized: "Google")
        case .yelp:       return String(localized: "Yelp")
        case .facebook:   return String(localized: "Facebook")
        case .instagram:  return String(localized: "Instagram")
        case .doorHanger: return String(localized: "Door Hanger")
        case .tradeShow:  return String(localized: "Trade Show")
        case .other:      return String(localized: "Other")
        }
    }
}

// MARK: - Client

enum ClientType: String, Codable, CaseIterable, Identifiable {
    case residential = "RESIDENTIAL"
    case commercial  = "COMMERCIAL"
    case multiFamily = "MULTI_FAMILY"
    case industrial  = "INDUSTRIAL"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .residential: return String(localized: "Residential")
        case .commercial:  return String(localized: "Commercial")
        case .multiFamily: return String(localized: "Multi-Family")
        case .industrial:  return String(localized: "Industrial")
        }
    }

    var icon: String {
        switch self {
        case .residential: return "house.fill"
        case .commercial:  return "building.2.fill"
        case .multiFamily: return "building.fill"
        case .industrial:  return "gearshape.2.fill"
        }
    }
}

// MARK: - Bid

enum BidStatus: String, Codable, CaseIterable, Identifiable {
    case draft    = "DRAFT"
    case sent     = "SENT"
    case viewed   = "VIEWED"
    case signed   = "SIGNED"
    case declined = "DECLINED"
    case expired  = "EXPIRED"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft:    return String(localized: "Draft")
        case .sent:     return String(localized: "Sent")
        case .viewed:   return String(localized: "Viewed")
        case .signed:   return String(localized: "Signed")
        case .declined: return String(localized: "Declined")
        case .expired:  return String(localized: "Expired")
        }
    }

    var color: Color {
        switch self {
        case .draft:    return Color(.systemGray3)
        case .sent:     return .blue
        case .viewed:   return EBPColor.warning
        case .signed:   return EBPColor.success
        case .declined: return EBPColor.danger
        case .expired:  return Color(.systemGray4)
        }
    }

    var icon: String {
        switch self {
        case .draft:    return "doc.text"
        case .sent:     return "paperplane.fill"
        case .viewed:   return "eye.fill"
        case .signed:   return "checkmark.seal.fill"
        case .declined: return "xmark.circle.fill"
        case .expired:  return "clock.badge.exclamationmark"
        }
    }

    /// Whether this bid can still be acted upon.
    var isPending: Bool { self == .sent || self == .viewed }
    var isDraft: Bool { self == .draft }
    var isTerminal: Bool { self == .signed || self == .declined || self == .expired }
}

enum BidTier: String, Codable, CaseIterable, Identifiable {
    case good   = "GOOD"
    case better = "BETTER"
    case best   = "BEST"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .good:   return String(localized: "Good")
        case .better: return String(localized: "Better")
        case .best:   return String(localized: "Best")
        }
    }

    var color: Color {
        switch self {
        case .good:   return .blue
        case .better: return EBPColor.accent
        case .best:   return EBPColor.gold
        }
    }

    /// Tier markup adder (0%, +5%, +10%).
    var markupAdder: Double {
        switch self {
        case .good:   return 0.0
        case .better: return 0.05
        case .best:   return 0.10
        }
    }
}

// MARK: - Coating System

enum CoatingSystem: String, Codable, CaseIterable, Identifiable {
    case singleCoatClear = "SINGLE_COAT_CLEAR"
    case twoCoatFlake    = "TWO_COAT_FLAKE"
    case fullMetallic    = "FULL_METALLIC"
    case quartz          = "QUARTZ"
    case polyaspartic    = "POLYASPARTIC"
    case commercialGrade = "COMMERCIAL_GRADE"
    case custom          = "CUSTOM"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .singleCoatClear: return String(localized: "Single Coat Clear")
        case .twoCoatFlake:    return String(localized: "Two Coat Flake")
        case .fullMetallic:    return String(localized: "Full Metallic")
        case .quartz:          return String(localized: "Quartz")
        case .polyaspartic:    return String(localized: "Polyaspartic")
        case .commercialGrade: return String(localized: "Commercial Grade")
        case .custom:          return String(localized: "Custom")
        }
    }

    var icon: String {
        switch self {
        case .singleCoatClear: return "drop.fill"
        case .twoCoatFlake:    return "sparkles"
        case .fullMetallic:    return "light.max"
        case .quartz:          return "diamond.fill"
        case .polyaspartic:    return "bolt.fill"
        case .commercialGrade: return "building.2.fill"
        case .custom:          return "paintbrush.fill"
        }
    }

    /// Typical number of coats for this system.
    var typicalCoats: Int {
        switch self {
        case .singleCoatClear: return 1
        case .twoCoatFlake:    return 2
        case .fullMetallic:    return 3
        case .quartz:          return 2
        case .polyaspartic:    return 2
        case .commercialGrade: return 2
        case .custom:          return 2
        }
    }
}

enum SurfaceCondition: String, Codable, CaseIterable, Identifiable {
    case excellent = "EXCELLENT"
    case good      = "GOOD"
    case fair      = "FAIR"
    case poor      = "POOR"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .excellent: return String(localized: "Excellent")
        case .good:      return String(localized: "Good")
        case .fair:      return String(localized: "Fair")
        case .poor:      return String(localized: "Poor")
        }
    }

    /// Pricing multiplier — worse condition = more prep = higher cost.
    var pricingMultiplier: Double {
        switch self {
        case .excellent: return 1.0
        case .good:      return 1.1
        case .fair:      return 1.25
        case .poor:      return 1.5
        }
    }
}

// MARK: - Job

enum JobStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled  = "SCHEDULED"
    case inProgress = "IN_PROGRESS"
    case punchList  = "PUNCH_LIST"
    case complete   = "COMPLETE"
    case invoiced   = "INVOICED"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scheduled:  return String(localized: "Scheduled")
        case .inProgress: return String(localized: "In Progress")
        case .punchList:  return String(localized: "Punch List")
        case .complete:   return String(localized: "Complete")
        case .invoiced:   return String(localized: "Invoiced")
        }
    }

    var color: Color {
        switch self {
        case .scheduled:  return .blue
        case .inProgress: return EBPColor.accent
        case .punchList:  return EBPColor.warning
        case .complete:   return EBPColor.success
        case .invoiced:   return .purple
        }
    }

    var icon: String {
        switch self {
        case .scheduled:  return "calendar"
        case .inProgress: return "hammer.fill"
        case .punchList:  return "checklist"
        case .complete:   return "checkmark.circle.fill"
        case .invoiced:   return "dollarsign.circle.fill"
        }
    }

    /// Whether this job is still active (not finished).
    var isActive: Bool { self == .scheduled || self == .inProgress || self == .punchList }
}

// MARK: - Invoice

enum InvoiceStatus: String, Codable, CaseIterable, Identifiable {
    case draft        = "DRAFT"
    case sent         = "SENT"
    case partiallyPaid = "PARTIALLY_PAID"
    case paid         = "PAID"
    case overdue      = "OVERDUE"
    case voided       = "VOIDED"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .draft:        return String(localized: "Draft")
        case .sent:         return String(localized: "Sent")
        case .partiallyPaid: return String(localized: "Partial")
        case .paid:         return String(localized: "Paid")
        case .overdue:      return String(localized: "Overdue")
        case .voided:       return String(localized: "Voided")
        }
    }

    var color: Color {
        switch self {
        case .draft:        return .secondary
        case .sent:         return .blue
        case .partiallyPaid: return EBPColor.warning
        case .paid:         return EBPColor.success
        case .overdue:      return EBPColor.danger
        case .voided:       return .gray
        }
    }

    var isOutstanding: Bool { self == .sent || self == .partiallyPaid || self == .overdue }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case card     = "CARD"
    case ach      = "ACH"
    case applePay = "APPLE_PAY"
    case check    = "CHECK"
    case cash     = "CASH"
    case other    = "OTHER"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .card:     return String(localized: "Credit Card")
        case .ach:      return String(localized: "Bank Transfer")
        case .applePay: return String(localized: "Apple Pay")
        case .check:    return String(localized: "Check")
        case .cash:     return String(localized: "Cash")
        case .other:    return String(localized: "Other")
        }
    }

    var icon: String {
        switch self {
        case .card:     return "creditcard.fill"
        case .ach:      return "building.columns.fill"
        case .applePay: return "apple.logo"
        case .check:    return "doc.text.fill"
        case .cash:     return "banknote.fill"
        case .other:    return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Photo

enum PhotoCategory: String, Codable, CaseIterable, Identifiable {
    case before          = "BEFORE"
    case during          = "DURING"
    case after           = "AFTER"
    case surfaceCondition = "SURFACE_CONDITION"
    case damage          = "DAMAGE"
    case marketing       = "MARKETING"
    case document        = "DOCUMENT"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .before:          return String(localized: "Before")
        case .during:          return String(localized: "During")
        case .after:           return String(localized: "After")
        case .surfaceCondition: return String(localized: "Surface")
        case .damage:          return String(localized: "Damage")
        case .marketing:       return String(localized: "Marketing")
        case .document:        return String(localized: "Document")
        }
    }
}
