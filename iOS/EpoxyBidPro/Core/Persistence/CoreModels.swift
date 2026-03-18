import Foundation
import SwiftData

// ═══════════════════════════════════════════════════════════════════════════════
// CoreModels.swift
// SwiftData @Model classes with typed enums, sync tracking, and updatedAt.
// Phase 2 rebuild — replaces raw String status fields with proper Swift enums.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Client ──────────────────────────────────────────────────────────────────

@Model final class Client {
    var id: UUID
    var firstName: String
    var lastName: String
    var company: String
    var email: String
    var phone: String
    var address: String
    var city: String
    var state: String
    var zip: String
    var clientTypeRaw: String
    var notes: String
    var tags: [String]
    var isVip: Bool
    var totalRevenue: Decimal
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    @Relationship(deleteRule: .cascade) var measurements: [Measurement]
    @Relationship(deleteRule: .cascade) var bids: [Bid]
    @Relationship(deleteRule: .cascade) var jobs: [Job]

    // Typed accessor
    var clientType: ClientType {
        get { ClientType(rawValue: clientTypeRaw) ?? .residential }
        set { clientTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        email: String = "",
        phone: String = "",
        address: String = "",
        city: String = "",
        state: String = "",
        zip: String = "",
        clientType: ClientType = .residential,
        notes: String = "",
        tags: [String] = [],
        isVip: Bool = false,
        totalRevenue: Decimal = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false,
        measurements: [Measurement] = [],
        bids: [Bid] = [],
        jobs: [Job] = []
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.state = state
        self.zip = zip
        self.clientTypeRaw = clientType.rawValue
        self.notes = notes
        self.tags = tags
        self.isVip = isVip
        self.totalRevenue = totalRevenue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
        self.measurements = measurements
        self.bids = bids
        self.jobs = jobs
    }

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (company.isEmpty ? "Unnamed Client" : company) : full
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Lead ────────────────────────────────────────────────────────────────────

@Model final class Lead {
    var id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var phone: String
    var company: String
    var address: String
    var statusRaw: String
    var sourceRaw: String
    var estimatedValue: Double
    var notes: String
    var lostReason: String
    var followUpAt: Date?
    var convertedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    // Typed accessors
    var status: LeadStatus {
        get { LeadStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    var source: LeadSource {
        get { LeadSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phone: String = "",
        company: String = "",
        address: String = "",
        status: LeadStatus = .new,
        source: LeadSource = .manual,
        estimatedValue: Double = 0,
        notes: String = "",
        lostReason: String = "",
        followUpAt: Date? = nil,
        convertedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.company = company
        self.address = address
        self.statusRaw = status.rawValue
        self.sourceRaw = source.rawValue
        self.estimatedValue = estimatedValue
        self.notes = notes
        self.lostReason = lostReason
        self.followUpAt = followUpAt
        self.convertedAt = convertedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
    }

    var displayName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var followUpDate: Date? {
        get { followUpAt }
        set { followUpAt = newValue }
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Measurement (LiDAR scan result) ─────────────────────────────────────────

@Model final class Measurement {
    var id: UUID
    var label: String
    var notes: String
    var totalSqFt: Double
    var scanDate: Date
    var floorPlanUrl: String
    var scanDataJson: String
    var isLidar: Bool
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    var client: Client?

    @Relationship(deleteRule: .cascade, inverse: \Area.measurement)
    var areas: [Area]

    init(
        id: UUID = UUID(),
        label: String = "",
        notes: String = "",
        totalSqFt: Double = 0,
        scanDate: Date = Date(),
        floorPlanUrl: String = "",
        scanDataJson: String = "{}",
        isLidar: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false,
        client: Client? = nil,
        areas: [Area] = []
    ) {
        self.id = id
        self.label = label
        self.notes = notes
        self.totalSqFt = totalSqFt
        self.scanDate = scanDate
        self.floorPlanUrl = floorPlanUrl
        self.scanDataJson = scanDataJson
        self.isLidar = isLidar
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
        self.client = client
        self.areas = areas
    }

    var areaCount: Int { areas.count }
    var computedTotal: Double { areas.reduce(0) { $0 + $1.squareFeet } }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Area (sub-room within a Measurement) ────────────────────────────────────

@Model final class Area {
    var id: UUID
    var name: String
    var squareFeet: Double
    var polygonJson: String
    var sortOrder: Int
    var capturedAt: Date

    var measurement: Measurement?

    init(
        id: UUID = UUID(),
        name: String = "",
        squareFeet: Double = 0,
        polygonJson: String = "[]",
        sortOrder: Int = 0,
        capturedAt: Date = Date(),
        measurement: Measurement? = nil
    ) {
        self.id = id
        self.name = name
        self.squareFeet = squareFeet
        self.polygonJson = polygonJson
        self.sortOrder = sortOrder
        self.capturedAt = capturedAt
        self.measurement = measurement
    }
}

// ─── Bid ─────────────────────────────────────────────────────────────────────

@Model final class Bid {
    var id: UUID
    var bidNumber: String
    var title: String
    var statusRaw: String
    var tierRaw: String
    var coatingSystemRaw: String
    var surfaceConditionRaw: String
    var totalSqFt: Double

    // Pricing
    var materialCost: Decimal
    var laborCost: Decimal
    var overheadCost: Decimal
    var markup: Decimal
    var taxRate: Decimal
    var taxAmount: Decimal
    var subtotal: Decimal
    var totalPrice: Decimal
    var profitMargin: Double
    var estimatedHours: Double

    // Proposal
    var executiveSummary: String
    var scopeNotes: String
    var validUntil: Date?
    var pdfUrl: String
    var sentAt: Date?
    var viewedAt: Date?
    var signedAt: Date?
    var declinedAt: Date?

    // AI
    var aiSuggestionsJson: String
    var aiRiskFlags: [String]
    var aiUpsells: [String]

    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    var client: Client?
    var measurement: Measurement?

    @Relationship(deleteRule: .cascade) var lineItems: [BidLineItem]
    var signature: BidSignature?

    // Typed accessors
    var status: BidStatus {
        get { BidStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var tier: BidTier {
        get { BidTier(rawValue: tierRaw) ?? .better }
        set { tierRaw = newValue.rawValue }
    }

    var coatingSystem: CoatingSystem {
        get { CoatingSystem(rawValue: coatingSystemRaw) ?? .singleCoatClear }
        set { coatingSystemRaw = newValue.rawValue }
    }

    var surfaceCondition: SurfaceCondition {
        get { SurfaceCondition(rawValue: surfaceConditionRaw) ?? .good }
        set { surfaceConditionRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        bidNumber: String = "",
        title: String = "",
        status: BidStatus = .draft,
        tier: BidTier = .better,
        coatingSystem: CoatingSystem = .singleCoatClear,
        surfaceCondition: SurfaceCondition = .good,
        totalSqFt: Double = 0,
        materialCost: Decimal = 0,
        laborCost: Decimal = 0,
        overheadCost: Decimal = 0,
        markup: Decimal = 0,
        taxRate: Decimal = 0,
        taxAmount: Decimal = 0,
        subtotal: Decimal = 0,
        totalPrice: Decimal = 0,
        profitMargin: Double = 0,
        estimatedHours: Double = 0,
        executiveSummary: String = "",
        scopeNotes: String = "",
        validUntil: Date? = nil,
        pdfUrl: String = "",
        sentAt: Date? = nil,
        viewedAt: Date? = nil,
        signedAt: Date? = nil,
        declinedAt: Date? = nil,
        aiSuggestionsJson: String = "{}",
        aiRiskFlags: [String] = [],
        aiUpsells: [String] = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false,
        client: Client? = nil,
        measurement: Measurement? = nil,
        lineItems: [BidLineItem] = [],
        signature: BidSignature? = nil
    ) {
        self.id = id
        self.bidNumber = bidNumber
        self.title = title
        self.statusRaw = status.rawValue
        self.tierRaw = tier.rawValue
        self.coatingSystemRaw = coatingSystem.rawValue
        self.surfaceConditionRaw = surfaceCondition.rawValue
        self.totalSqFt = totalSqFt
        self.materialCost = materialCost
        self.laborCost = laborCost
        self.overheadCost = overheadCost
        self.markup = markup
        self.taxRate = taxRate
        self.taxAmount = taxAmount
        self.subtotal = subtotal
        self.totalPrice = totalPrice
        self.profitMargin = profitMargin
        self.estimatedHours = estimatedHours
        self.executiveSummary = executiveSummary
        self.scopeNotes = scopeNotes
        self.validUntil = validUntil
        self.pdfUrl = pdfUrl
        self.sentAt = sentAt
        self.viewedAt = viewedAt
        self.signedAt = signedAt
        self.declinedAt = declinedAt
        self.aiSuggestionsJson = aiSuggestionsJson
        self.aiRiskFlags = aiRiskFlags
        self.aiUpsells = aiUpsells
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
        self.client = client
        self.measurement = measurement
        self.lineItems = lineItems
        self.signature = signature
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Job ─────────────────────────────────────────────────────────────────────

@Model final class Job {
    var id: UUID
    var jobNumber: String
    var title: String
    var statusRaw: String
    var coatingSystemRaw: String
    var scheduledDate: Date?
    var startedAt: Date?
    var completedAt: Date?
    var totalSqFt: Double
    var address: String
    var assignedCrew: [String]
    var revenue: Decimal
    var actualCost: Decimal
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    var client: Client?
    var bid: Bid?
    @Relationship(deleteRule: .cascade) var checklistItems: [JobChecklistItem]

    // Typed accessors
    var status: JobStatus {
        get { JobStatus(rawValue: statusRaw) ?? .scheduled }
        set { statusRaw = newValue.rawValue }
    }

    var coatingSystem: CoatingSystem {
        get { CoatingSystem(rawValue: coatingSystemRaw) ?? .singleCoatClear }
        set { coatingSystemRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        jobNumber: String = "",
        title: String = "",
        status: JobStatus = .scheduled,
        coatingSystem: CoatingSystem = .singleCoatClear,
        scheduledDate: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        totalSqFt: Double = 0,
        address: String = "",
        assignedCrew: [String] = [],
        revenue: Decimal = 0,
        actualCost: Decimal = 0,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false,
        client: Client? = nil,
        bid: Bid? = nil,
        checklistItems: [JobChecklistItem] = []
    ) {
        self.id = id
        self.jobNumber = jobNumber
        self.title = title
        self.statusRaw = status.rawValue
        self.coatingSystemRaw = coatingSystem.rawValue
        self.scheduledDate = scheduledDate
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.totalSqFt = totalSqFt
        self.address = address
        self.assignedCrew = assignedCrew
        self.revenue = revenue
        self.actualCost = actualCost
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
        self.client = client
        self.bid = bid
        self.checklistItems = checklistItems
    }

    var profitMargin: Double {
        guard revenue > 0 else { return 0 }
        let revenueDouble = NSDecimalNumber(decimal: revenue).doubleValue
        let costDouble = NSDecimalNumber(decimal: actualCost).doubleValue
        return ((revenueDouble - costDouble) / revenueDouble) * 100
    }

    var checklistProgress: Double {
        guard !checklistItems.isEmpty else { return 0 }
        let completed = checklistItems.filter(\.isComplete).count
        return Double(completed) / Double(checklistItems.count)
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Job Checklist Item ──────────────────────────────────────────────────────

@Model final class JobChecklistItem {
    var id: UUID
    var title: String
    var isComplete: Bool
    var completedAt: Date?
    var sortOrder: Int
    var photoUrl: String
    var notes: String

    init(
        id: UUID = UUID(),
        title: String = "",
        isComplete: Bool = false,
        completedAt: Date? = nil,
        sortOrder: Int = 0,
        photoUrl: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.sortOrder = sortOrder
        self.photoUrl = photoUrl
        self.notes = notes
    }
}

// ─── Invoice ─────────────────────────────────────────────────────────────────

@Model final class Invoice {
    var id: UUID
    var invoiceNumber: String
    var statusRaw: String
    var issueDate: Date
    var dueDate: Date
    var paidDate: Date?

    // Amounts
    var subtotal: Decimal
    var taxRate: Decimal
    var taxAmount: Decimal
    var totalAmount: Decimal
    var amountPaid: Decimal
    var depositAmount: Decimal
    var depositPaid: Bool

    // Payment
    var stripePaymentLinkUrl: String
    var stripePaymentIntentId: String
    var paymentMethodRaw: String

    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var backendId: String
    var isSynced: Bool

    var client: Client?
    var job: Job?
    @Relationship(deleteRule: .cascade) var lineItems: [InvoiceLineItem]

    // Typed accessors
    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod? {
        get { PaymentMethod(rawValue: paymentMethodRaw) }
        set { paymentMethodRaw = newValue?.rawValue ?? "" }
    }

    init(
        id: UUID = UUID(),
        invoiceNumber: String = "",
        status: InvoiceStatus = .draft,
        issueDate: Date = Date(),
        dueDate: Date = Date(),
        paidDate: Date? = nil,
        subtotal: Decimal = 0,
        taxRate: Decimal = 0.08,
        taxAmount: Decimal = 0,
        totalAmount: Decimal = 0,
        amountPaid: Decimal = 0,
        depositAmount: Decimal = 0,
        depositPaid: Bool = false,
        stripePaymentLinkUrl: String = "",
        stripePaymentIntentId: String = "",
        paymentMethod: PaymentMethod? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        backendId: String = "",
        isSynced: Bool = false,
        client: Client? = nil,
        job: Job? = nil,
        lineItems: [InvoiceLineItem] = []
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.statusRaw = status.rawValue
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.subtotal = subtotal
        self.taxRate = taxRate
        self.taxAmount = taxAmount
        self.totalAmount = totalAmount
        self.amountPaid = amountPaid
        self.depositAmount = depositAmount
        self.depositPaid = depositPaid
        self.stripePaymentLinkUrl = stripePaymentLinkUrl
        self.stripePaymentIntentId = stripePaymentIntentId
        self.paymentMethodRaw = paymentMethod?.rawValue ?? ""
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.backendId = backendId
        self.isSynced = isSynced
        self.client = client
        self.job = job
        self.lineItems = lineItems
    }

    var balanceDue: Decimal {
        totalAmount - amountPaid
    }

    var isOverdue: Bool {
        dueDate < Date() && balanceDue > 0 && status != .paid && status != .void
    }

    func markUpdated() {
        updatedAt = Date()
        isSynced = false
    }
}

// ─── Invoice Line Item ───────────────────────────────────────────────────────

@Model final class InvoiceLineItem {
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
