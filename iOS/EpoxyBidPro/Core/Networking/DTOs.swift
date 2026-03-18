import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// DTOs.swift
// Codable request/response types for API communication.
// These are separate from SwiftData models — they map to backend JSON shapes.
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Auth

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: UserDTO
    let business: BusinessDTO?
}

struct UserDTO: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    let phone: String?
    let avatarUrl: String?
    let role: String
}

struct BusinessDTO: Codable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let website: String?
    let address: String?
    let city: String?
    let state: String?
    let zip: String?
    let licenseNumber: String?
    let taxRate: Double?
    let defaultMarkup: Double?
    let defaultMargin: Double?
    let laborRate: Double?
    let overheadRate: Double?
    let mobilizationFee: Double?
    let minimumJobPrice: Double?
    let brandColor: String?
    let bidPrefix: String?
    let invoicePrefix: String?
}

// MARK: - Dashboard

struct DashboardDTO: Decodable {
    let monthRevenue: Double
    let openBids: Int
    let activeJobs: Int
    let overdueInvoices: Int
    let recentActivity: [ActivityDTO]?
}

struct ActivityDTO: Decodable {
    let id: String
    let action: String
    let entityType: String
    let entityId: String?
    let createdAt: String
    let metadata: [String: String]?
}

// MARK: - Bid

struct BidGenerateRequest: Encodable {
    let clientId: String?
    let measurementId: String?
    let coatingSystem: String
    let surfaceCondition: String
    let totalSqFt: Double
    let tier: String
}

struct PricingPreviewRequest: Encodable {
    let coatingSystem: String
    let surfaceCondition: String
    let totalSqFt: Double
    let prepComplexity: String?
    let accessDifficulty: String?
}

struct PricingResultDTO: Decodable {
    let tiers: TierBreakdownDTO
    let wasteFactorUsed: Double
    let shoppingList: [ShoppingItemDTO]?
}

struct TierBreakdownDTO: Decodable {
    let good: TierPriceDTO
    let better: TierPriceDTO
    let best: TierPriceDTO
}

struct TierPriceDTO: Decodable {
    let materialCost: Double
    let laborCost: Double
    let overheadCost: Double
    let subtotal: Double
    let markup: Double
    let taxAmount: Double
    let totalPrice: Double
    let profitMargin: Double
    let estimatedHours: Double?
}

struct ShoppingItemDTO: Decodable {
    let material: String
    let quantity: Double
    let unit: String
    let cost: Double
}

struct AISuggestionsDTO: Decodable {
    let summary: String
    let riskFlags: [String]
    let upsells: [String]
    let marketContext: String?
}

// MARK: - Client

struct CreateClientRequest: Encodable {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let company: String
    let address: String
    let city: String
    let state: String
    let zip: String
    let clientType: String
}

struct ClientDTO: Decodable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let company: String
    let clientType: String
    let totalRevenue: Double?
    let createdAt: String
}

// MARK: - Lead

struct CreateLeadRequest: Encodable {
    let firstName: String
    let lastName: String
    let email: String
    let phone: String
    let company: String
    let address: String
    let source: String
    let estimatedValue: Double
    let notes: String
}

// MARK: - Measurement

struct CreateMeasurementRequest: Encodable {
    let clientId: String?
    let name: String
    let totalSqFt: Double
    let isLidar: Bool
    let scanDataJson: String?
    let areas: [CreateAreaRequest]
}

struct CreateAreaRequest: Encodable {
    let label: String
    let sqFt: Double
    let polygonJson: String?
    let order: Int
}

// MARK: - Invoice

struct CreateInvoiceRequest: Encodable {
    let clientId: String
    let jobId: String?
    let dueDate: String
    let lineItems: [InvoiceLineItemRequest]
    let depositAmount: Double?
    let notes: String?
}

struct InvoiceLineItemRequest: Encodable {
    let description: String
    let quantity: Double
    let unitPrice: Double
}

// MARK: - Payment

struct RecordPaymentRequest: Encodable {
    let invoiceId: String
    let amount: Double
    let method: String
    let notes: String?
}

// MARK: - Assistant

struct AssistantResponse: Decodable {
    let reply: String
}
