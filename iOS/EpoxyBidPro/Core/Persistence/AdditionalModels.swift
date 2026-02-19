import Foundation
import SwiftData

// ─── Supporting Bid Models ────────────────────────────────────────────────────

@Model final class BidLineItem {
    var id: UUID = UUID()
    var description: String = ""
    var quantity: Double = 1
    var unitPrice: Decimal = 0
    var amount: Decimal = 0
    var sortOrder: Int = 0
}

@Model final class BidSignature {
    var id: UUID = UUID()
    var signerName: String = ""
    var signedAt: Date = Date()
    var signatureDataBase64: String = ""  // PNG base64-encoded signature image
    var ipAddress: String = ""
}

// ─── Other Domain Models (stubs — expanded in later phases) ──────────────────

@Model final class Invoice {
    var id: UUID = UUID()
    var number: String = ""
    var totalAmount: Decimal = 0
    var status: String = "DRAFT"
    var createdAt: Date = Date()
    var backendId: String = ""
    var isSynced: Bool = false
}

@Model final class Payment {
    var id: UUID = UUID()
    var amount: Decimal = 0
    var method: String = "CASH"
    var paidAt: Date = Date()
    var backendId: String = ""
    var isSynced: Bool = false
}

@Model final class Photo {
    var id: UUID = UUID()
    var remoteURL: String = ""
    var localPath: String = ""
    var category: String = "GENERAL"
    var caption: String = ""
    var createdAt: Date = Date()
    var isSynced: Bool = false
}

@Model final class CrewMember {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var role: String = ""
    var isActive: Bool = true
    var backendId: String = ""
    var isSynced: Bool = false
}

@Model final class Material {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var category: String = ""
    var costPerUnit: Decimal = 0
    var coverageRate: Double = 0
    var unit: String = "gallon"
    var backendId: String = ""
    var isSynced: Bool = false
}

@Model final class Template {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = "BID"
    var contentJson: String = "{}"
    var isDefault: Bool = false
    var backendId: String = ""
    var isSynced: Bool = false
}
