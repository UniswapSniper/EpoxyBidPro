import Foundation
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════════
// AdditionalModels.swift
// Supporting SwiftData models with typed enums and sync tracking.
// Phase 2 rebuild — consistent patterns across all models.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Bid Line Item ───────────────────────────────────────────────────────────

@Model final class BidLineItem {
    var id: UUID
    var itemDescription: String
    var quantity: Double
    var unitPrice: Decimal
    var amount: Decimal
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        itemDescription: String = "",
        quantity: Double = 1,
        unitPrice: Decimal = 0,
        amount: Decimal = 0,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.amount = amount
        self.sortOrder = sortOrder
    }
}

// ─── Bid Signature ───────────────────────────────────────────────────────────

@Model final class BidSignature {
    var id: UUID
    var signerName: String
    var signedAt: Date
    var signatureDataBase64: String
    var ipAddress: String

    init(
        id: UUID = UUID(),
        signerName: String = "",
        signedAt: Date = Date(),
        signatureDataBase64: String = "",
        ipAddress: String = ""
    ) {
        self.id = id
        self.signerName = signerName
        self.signedAt = signedAt
        self.signatureDataBase64 = signatureDataBase64
        self.ipAddress = ipAddress
    }
}

// ─── Payment ─────────────────────────────────────────────────────────────────

@Model final class Payment {
    var id: UUID
    var amount: Decimal
    var methodRaw: String
    var paidAt: Date
    var notes: String
    var stripePaymentIntentId: String
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    var invoice: Invoice?

    // Typed accessor
    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .cash }
        set { methodRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal = 0,
        method: PaymentMethod = .cash,
        paidAt: Date = Date(),
        notes: String = "",
        stripePaymentIntentId: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false,
        invoice: Invoice? = nil
    ) {
        self.id = id
        self.amount = amount
        self.methodRaw = method.rawValue
        self.paidAt = paidAt
        self.notes = notes
        self.stripePaymentIntentId = stripePaymentIntentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
        self.invoice = invoice
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Photo ───────────────────────────────────────────────────────────────────

@Model final class Photo {
    var id: UUID
    var remoteURL: String
    var localPath: String
    var categoryRaw: String
    var caption: String
    var createdAt: Date
    var updatedAt: Date
    var isSynced: Bool

    // Typed accessor
    var category: PhotoCategory {
        get { PhotoCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        remoteURL: String = "",
        localPath: String = "",
        category: PhotoCategory = .general,
        caption: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.remoteURL = remoteURL
        self.localPath = localPath
        self.categoryRaw = category.rawValue
        self.caption = caption
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSynced = isSynced
    }
}

// ─── Crew Member ─────────────────────────────────────────────────────────────

@Model final class CrewMember {
    var id: UUID
    var firstName: String
    var lastName: String
    var phone: String
    var email: String
    var role: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        phone: String = "",
        email: String = "",
        role: String = "",
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.email = email
        self.role = role
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
    }

    var displayName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Material ────────────────────────────────────────────────────────────────

@Model final class Material {
    var id: UUID
    var name: String
    var brand: String
    var category: String
    var costPerUnit: Decimal
    var coverageRate: Double // sqft per unit
    var unit: String
    var coats: Int
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        brand: String = "",
        category: String = "",
        costPerUnit: Decimal = 0,
        coverageRate: Double = 0,
        unit: String = "gallon",
        coats: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.costPerUnit = costPerUnit
        self.coverageRate = coverageRate
        self.unit = unit
        self.coats = coats
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Template ────────────────────────────────────────────────────────────────

@Model final class Template {
    var id: UUID
    var name: String
    var type: String // "BID", "INVOICE", "EMAIL", "SMS"
    var contentJson: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        type: String = "BID",
        contentJson: String = "{}",
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.contentJson = contentJson
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}
