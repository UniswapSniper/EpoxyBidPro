import Foundation
import SwiftData

// ─── Client ──────────────────────────────────────────────────────────────────

@Model final class Client {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var clientType: String = "RESIDENTIAL"   // RESIDENTIAL | COMMERCIAL | MULTI_FAMILY | INDUSTRIAL
    var notes: String = ""
    var tags: [String] = []
    var isVip: Bool = false
    var totalRevenue: Decimal = 0
    var createdAt: Date = Date()
    var backendId: String = ""
    var isSynced: Bool = false

    @Relationship(deleteRule: .cascade) var measurements: [Measurement] = []
    @Relationship(deleteRule: .cascade) var bids: [Bid] = []
    @Relationship(deleteRule: .cascade) var jobs: [Job] = []

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (company.isEmpty ? "Unnamed Client" : company) : full
    }
}

// ─── Lead ────────────────────────────────────────────────────────────────────

@Model final class Lead {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var status: String = "NEW"             // NEW | CONTACTED | SITE_VISIT | BID_SENT | WON | LOST
    var source: String = "MANUAL"          // REFERRAL | GOOGLE | YELP | FACEBOOK | DOOR_HANGER | MANUAL
    var estimatedValue: Decimal = 0
    var notes: String = ""
    var lostReason: String = ""
    var followUpAt: Date? = nil
    var createdAt: Date = Date()
    var backendId: String = ""
    var isSynced: Bool = false

    var displayName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

// ─── Measurement (LiDAR scan result) ─────────────────────────────────────────

@Model final class Measurement {
    var id: UUID = UUID()
    var label: String = ""               // e.g. "123 Main St – Garage"
    var notes: String = ""
    var totalSqFt: Double = 0
    var scanDate: Date = Date()
    var floorPlanUrl: String = ""        // remote URL after upload
    var scanDataJson: String = "{}"      // raw polygon JSON from LiDAR session
    var backendId: String = ""
    var isSynced: Bool = false

    var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \Area.measurement)
    var areas: [Area] = []

    var areaCount: Int { areas.count }
    var computedTotal: Double { areas.reduce(0) { $0 + $1.squareFeet } }
}

// ─── Area (sub-room within a Measurement) ────────────────────────────────────

@Model final class Area {
    var id: UUID = UUID()
    var name: String = ""                // e.g. "Garage", "Basement"
    var squareFeet: Double = 0
    var polygonJson: String = "[]"       // JSON: [[x,z], ...] vertices in meters
    var sortOrder: Int = 0
    var capturedAt: Date = Date()

    var measurement: Measurement?
}

// ─── Bid ─────────────────────────────────────────────────────────────────────

@Model final class Bid {
    var id: UUID = UUID()
    var bidNumber: String = ""            // e.g. "BID-1001"
    var title: String = ""
    var status: String = "DRAFT"          // DRAFT | SENT | VIEWED | SIGNED | DECLINED | EXPIRED
    var tier: String = "BETTER"           // GOOD | BETTER | BEST
    var coatingSystem: String = ""
    var totalSqFt: Double = 0

    // Pricing
    var materialCost: Decimal = 0
    var laborCost: Decimal = 0
    var markup: Decimal = 0
    var taxRate: Decimal = 0
    var taxAmount: Decimal = 0
    var subtotal: Decimal = 0
    var totalPrice: Decimal = 0
    var profitMargin: Decimal = 0

    // Proposal
    var executiveSummary: String = ""
    var scopeNotes: String = ""
    var validUntil: Date? = nil
    var pdfUrl: String = ""
    var sentAt: Date? = nil
    var viewedAt: Date? = nil
    var signedAt: Date? = nil
    var declinedAt: Date? = nil

    // AI
    var aiSuggestionsJson: String = "{}"
    var aiRiskFlags: [String] = []
    var aiUpsells: [String] = []

    var notes: String = ""
    var createdAt: Date = Date()
    var backendId: String = ""
    var isSynced: Bool = false

    var client: Client?
    var measurement: Measurement?

    @Relationship(deleteRule: .cascade) var lineItems: [BidLineItem] = []
    var signature: BidSignature? = nil
}

// ─── Job ─────────────────────────────────────────────────────────────────────

@Model final class Job {
    var id: UUID = UUID()
    var title: String = ""
    var status: String = "SCHEDULED"   // SCHEDULED | IN_PROGRESS | PUNCH_LIST | COMPLETE | PAID
    var scheduledDate: Date? = nil
    var startedAt: Date? = nil
    var completedAt: Date? = nil
    var totalSqFt: Double = 0
    var address: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var backendId: String = ""
    var isSynced: Bool = false

    var client: Client?
    var bid: Bid?
}
