import Foundation
import SwiftData

// ─── Supporting Bid Models ────────────────────────────────────────────────────

@Model final class BidLineItem {
    var id: UUID
    var itemDescription: String  // Changed from 'description' (reserved name)
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

// ─── JobTimeEntry ─────────────────────────────────────────────────────────────
// Tracks crew clock-in / clock-out records per job.

@Model final class JobTimeEntry {
    var id: UUID
    var crewMember: String
    var clockedIn: Date
    var clockedOut: Date?
    var notes: String
    var jobId: UUID

    init(
        id: UUID = UUID(),
        crewMember: String = "",
        clockedIn: Date = Date(),
        clockedOut: Date? = nil,
        notes: String = "",
        jobId: UUID = UUID()
    ) {
        self.id = id
        self.crewMember = crewMember
        self.clockedIn = clockedIn
        self.clockedOut = clockedOut
        self.notes = notes
        self.jobId = jobId
    }

    var durationHours: Double {
        let end = clockedOut ?? Date()
        return end.timeIntervalSince(clockedIn) / 3600
    }

    var isActive: Bool { clockedOut == nil }
}

// ─── JobMaterial ──────────────────────────────────────────────────────────────
// Per-job materials / equipment checklist item.

@Model final class JobMaterial {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var estimatedCost: Decimal
    var isAcquired: Bool
    var notes: String
    var sortOrder: Int
    var jobId: UUID

    init(
        id: UUID = UUID(),
        name: String = "",
        quantity: Double = 1,
        unit: String = "gal",
        estimatedCost: Decimal = 0,
        isAcquired: Bool = false,
        notes: String = "",
        sortOrder: Int = 0,
        jobId: UUID = UUID()
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.estimatedCost = estimatedCost
        self.isAcquired = isAcquired
        self.notes = notes
        self.sortOrder = sortOrder
        self.jobId = jobId
    }
}

// ─── BidVersion ───────────────────────────────────────────────────────────────
// Snapshot record capturing each time a bid is cloned or sent as a new version.

@Model final class BidVersion {
    var id: UUID
    var bidId: UUID
    var versionNumber: Int
    var snapshotJson: String   // JSON summary of key pricing at that version
    var createdAt: Date
    var changeNote: String

    init(
        id: UUID = UUID(),
        bidId: UUID = UUID(),
        versionNumber: Int = 1,
        snapshotJson: String = "{}",
        createdAt: Date = Date(),
        changeNote: String = ""
    ) {
        self.id = id
        self.bidId = bidId
        self.versionNumber = versionNumber
        self.snapshotJson = snapshotJson
        self.createdAt = createdAt
        self.changeNote = changeNote
    }
}

// ─── Other Domain Models (stubs — expanded in later phases) ──────────────────
// NOTE: Invoice and InvoiceLineItem are in CoreModels.swift

@Model final class Payment {
    var id: UUID
    var amount: Decimal
    var method: String
    var paidAt: Date
    var backendId: String
    var isSynced: Bool
    
    init(
        id: UUID = UUID(),
        amount: Decimal = 0,
        method: String = "CASH",
        paidAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.method = method
        self.paidAt = paidAt
        self.backendId = backendId
        self.isSynced = isSynced
    }
}

@Model final class Photo {
    var id: UUID
    var remoteURL: String
    var localPath: String
    var category: String
    var caption: String
    var createdAt: Date
    var isSynced: Bool
    
    init(
        id: UUID = UUID(),
        remoteURL: String = "",
        localPath: String = "",
        category: String = "GENERAL",
        caption: String = "",
        createdAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.remoteURL = remoteURL
        self.localPath = localPath
        self.category = category
        self.caption = caption
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
}

@Model final class CrewMember {
    var id: UUID
    var firstName: String
    var lastName: String
    var role: String
    var isActive: Bool
    var backendId: String
    var isSynced: Bool
    
    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        role: String = "",
        isActive: Bool = true,
        backendId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.isActive = isActive
        self.backendId = backendId
        self.isSynced = isSynced
    }
}

@Model final class Material {
    var id: UUID
    var name: String
    var brand: String
    var category: String
    var costPerUnit: Decimal
    var coverageRate: Double
    var unit: String
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
        self.backendId = backendId
        self.isSynced = isSynced
    }
}

@Model final class Template {
    var id: UUID
    var name: String
    var type: String
    var contentJson: String
    var isDefault: Bool
    var backendId: String
    var isSynced: Bool
    
    init(
        id: UUID = UUID(),
        name: String = "",
        type: String = "BID",
        contentJson: String = "{}",
        isDefault: Bool = false,
        backendId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.contentJson = contentJson
        self.isDefault = isDefault
        self.backendId = backendId
        self.isSynced = isSynced
    }
}
