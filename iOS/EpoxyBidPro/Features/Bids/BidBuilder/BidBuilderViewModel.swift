import Foundation
import SwiftUI
import SwiftData
import Combine

// ─── BidBuilderViewModel ─────────────────────────────────────────────────────
// State & logic for the multi-step Bid Builder wizard.
// Drives pricing calculations, AI suggestions, and final bid persistence.

@MainActor
final class BidBuilderViewModel: ObservableObject {

    // MARK: - Step 1: Client

    @Published var selectedClient: Client? = nil

    // MARK: - Step 2: Measurement

    @Published var selectedMeasurement: Measurement? = nil
    @Published var manualAreas: [ManualArea] = [ManualArea(name: "Area 1", sqFt: 0)]

    struct ManualArea: Identifiable {
        let id = UUID()
        var name: String
        var sqFt: Double
    }

    var totalSqFt: Double {
        if let m = selectedMeasurement {
            return m.computedTotal > 0 ? m.computedTotal : m.totalSqFt
        }
        return manualAreas.reduce(0) { $0 + $1.sqFt }
    }

    var areaBreakdown: [(name: String, sqFt: Double)] {
        if let m = selectedMeasurement, !m.areas.isEmpty {
            return m.areas.map { ($0.name, $0.squareFeet) }
        }
        return manualAreas.filter { $0.sqFt > 0 }.map { ($0.name, $0.sqFt) }
    }

    // MARK: - Step 3: Coating System

    @Published var selectedCoatingSystem: CoatingSystemOption? = nil

    enum CoatingSystemOption: String, CaseIterable, Identifiable {
        case singleCoatClear   = "SINGLE_COAT_CLEAR"
        case twoCoatFlake      = "TWO_COAT_FLAKE"
        case fullMetallic      = "FULL_METALLIC"
        case quartz            = "QUARTZ"
        case polyaspartic      = "POLYASPARTIC"
        case commercialGrade   = "COMMERCIAL_GRADE"
        case custom            = "CUSTOM"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .singleCoatClear: return NSLocalizedString("coating.single.clear", comment: "")
            case .twoCoatFlake:    return NSLocalizedString("coating.two.flake", comment: "")
            case .fullMetallic:    return NSLocalizedString("coating.metallic", comment: "")
            case .quartz:          return NSLocalizedString("coating.quartz", comment: "")
            case .polyaspartic:    return NSLocalizedString("coating.polyaspartic", comment: "")
            case .commercialGrade: return NSLocalizedString("coating.commercial", comment: "")
            case .custom:          return NSLocalizedString("coating.custom", comment: "")
            }
        }

        var description: String {
            switch self {
            case .singleCoatClear: return NSLocalizedString("desc.single.clear", comment: "")
            case .twoCoatFlake:    return NSLocalizedString("desc.two.flake", comment: "")
            case .fullMetallic:    return NSLocalizedString("desc.metallic", comment: "")
            case .quartz:          return NSLocalizedString("desc.quartz", comment: "")
            case .polyaspartic:    return NSLocalizedString("desc.polyaspartic", comment: "")
            case .commercialGrade: return NSLocalizedString("desc.commercial", comment: "")
            case .custom:          return NSLocalizedString("desc.custom", comment: "")
            }
        }

        var icon: String {
            switch self {
            case .singleCoatClear: return "drop.fill"
            case .twoCoatFlake:    return "sparkles"
            case .fullMetallic:    return "diamond.fill"
            case .quartz:          return "cube.fill"
            case .polyaspartic:    return "bolt.fill"
            case .commercialGrade: return "building.2.fill"
            case .custom:          return "slider.horizontal.3"
            }
        }

        var priceRange: String {
            switch self {
            case .singleCoatClear: return "$3–5 / sq ft"
            case .twoCoatFlake:    return "$5–8 / sq ft"
            case .fullMetallic:    return "$8–14 / sq ft"
            case .quartz:          return "$6–10 / sq ft"
            case .polyaspartic:    return "$7–12 / sq ft"
            case .commercialGrade: return "$5–9 / sq ft"
            case .custom:          return "Varies"
            }
        }

        var tintColor: Color {
            switch self {
            case .singleCoatClear: return .blue
            case .twoCoatFlake:    return .indigo
            case .fullMetallic:    return EBPColor.gold
            case .quartz:          return .teal
            case .polyaspartic:    return .orange
            case .commercialGrade: return .gray
            case .custom:          return EBPColor.primary
            }
        }
    }

    // MARK: - Step 4: Surface Prep

    @Published var surfaceCondition: SurfaceConditionOption = .good
    @Published var prepComplexity: PrepComplexityOption = .standard
    @Published var accessDifficulty: AccessOption = .normal
    @Published var isComplexLayout: Bool = false

    enum SurfaceConditionOption: String, CaseIterable, Identifiable {
        case excellent = "EXCELLENT"
        case good      = "GOOD"
        case fair      = "FAIR"
        case poor      = "POOR"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .excellent: return NSLocalizedString("excellent", comment: "")
            case .good:      return NSLocalizedString("good", comment: "")
            case .fair:      return NSLocalizedString("fair", comment: "")
            case .poor:      return NSLocalizedString("poor", comment: "")
            }
        }
        var description: String {
            switch self {
            case .excellent: return NSLocalizedString("desc.excellent", comment: "")
            case .good:      return NSLocalizedString("desc.good", comment: "")
            case .fair:      return NSLocalizedString("desc.fair", comment: "")
            case .poor:      return NSLocalizedString("desc.poor", comment: "")
            }
        }
        var icon: String {
            switch self {
            case .excellent: return "star.fill"
            case .good:      return "hand.thumbsup.fill"
            case .fair:      return "exclamationmark.triangle.fill"
            case .poor:      return "xmark.octagon.fill"
            }
        }
        var tint: Color {
            switch self {
            case .excellent: return EBPColor.success
            case .good:      return .blue
            case .fair:      return EBPColor.warning
            case .poor:      return EBPColor.danger
            }
        }
    }

    enum PrepComplexityOption: String, CaseIterable, Identifiable {
        case light    = "LIGHT"
        case standard = "STANDARD"
        case heavy    = "HEAVY"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .light:    return NSLocalizedString("light", comment: "")
            case .standard: return NSLocalizedString("standard", comment: "")
            case .heavy:    return NSLocalizedString("heavy", comment: "")
            }
        }
    }

    enum AccessOption: String, CaseIterable, Identifiable {
        case easy      = "EASY"
        case normal    = "NORMAL"
        case difficult = "DIFFICULT"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .easy:      return NSLocalizedString("easy", comment: "")
            case .normal:    return NSLocalizedString("normal", comment: "")
            case .difficult: return NSLocalizedString("difficult", comment: "")
            }
        }
    }

    // MARK: - Step 5: Pricing

    @Published var selectedTier: String = "BETTER"   // GOOD | BETTER | BEST
    @Published var crewCount: Int = 2
    @Published var estimatedHours: Double = 0
    @Published var pricingResult: PricingResult? = nil
    @Published var isGeneratingPricing: Bool = false

    struct TierOption: Identifiable {
        let id: String
        let tier: String
        let totalPrice: Decimal
        let profitMargin: Double
        let subtotal: Decimal
        let markup: Decimal
        let taxAmount: Decimal
    }

    struct PricingResult {
        let materialCost: Decimal
        let laborCost: Decimal
        let overheadCost: Decimal
        let selectedTier: TierOption
        let options: [TierOption]
        let shoppingList: [(label: String, quantity: Double, unit: String)]
    }

    // MARK: - Step 6: AI Insights

    @Published var aiRiskFlags: [String] = []
    @Published var aiUpsells: [String] = []
    @Published var aiSummary: String = ""

    // MARK: - Step 7: Line Items

    @Published var lineItems: [EditableLineItem] = []

    struct EditableLineItem: Identifiable {
        let id = UUID()
        var category: String
        var itemDescription: String
        var quantity: Double
        var unitPrice: Decimal
        var unit: String

        var amount: Decimal { Decimal(quantity) * unitPrice }
    }

    // MARK: - Misc

    @Published var bidTitle: String = ""
    @Published var scopeNotes: String = ""
    @Published var validDays: Int = 30
    @Published var errorMessage: String? = nil

    var hasUnsavedChanges: Bool {
        selectedClient != nil || totalSqFt > 0 || selectedCoatingSystem != nil || pricingResult != nil
    }

    // MARK: - Auto Estimate Hours

    func autoEstimateHours() -> Double {
        let sqFt = totalSqFt
        guard sqFt > 0 else { return 8 }
        return Double(Int(ceil(sqFt / 200))) * 2
    }

    // MARK: - Calculate Pricing (local engine — mirrors backend logic)

    func calculatePricing() async {
        isGeneratingPricing = true
        defer { isGeneratingPricing = false }

        // Small delay for UI feel
        try? await Task.sleep(for: .milliseconds(600))

        let sqFt = totalSqFt
        guard sqFt > 0 else { return }

        if estimatedHours <= 0 {
            estimatedHours = autoEstimateHours()
        }

        // Default pricing settings (would be loaded from backend/settings in production)
        let laborRate: Decimal = 55
        let overheadRate: Decimal = 0.15
        let defaultMarkup: Decimal = 0.25
        let taxRate: Decimal = 0.08
        let mobilizationFee: Decimal = 150
        let wasteFactorStd: Decimal = 0.10
        let wasteFactorCpx: Decimal = 0.15

        let wasteFactor = isComplexLayout ? wasteFactorCpx : wasteFactorStd

        // Derive material cost from coating system defaults
        let (coverageRate, costPerUnit, numCoats) = materialDefaults(for: selectedCoatingSystem)
        let rawMaterial = Decimal(sqFt) / Decimal(coverageRate) * Decimal(numCoats) * costPerUnit
        let materialCost = rawMaterial * (1 + wasteFactor)

        // Condition / coating / prep / access multipliers
        let condMult = conditionMultiplier(surfaceCondition)
        let coatMult = coatingMultiplier(selectedCoatingSystem)
        let prepMult = prepMultiplier(prepComplexity)
        let accessMult = accessMultiplier(accessDifficulty)

        let adjustedHours = Decimal(estimatedHours) * condMult * coatMult * prepMult * accessMult
        let laborCost = adjustedHours * laborRate * Decimal(max(1, crewCount))
        let overheadCost = (materialCost + laborCost) * overheadRate
        let baseSubtotal = materialCost + laborCost + overheadCost + mobilizationFee

        let tierAdders: [(String, Decimal)] = [("GOOD", 0), ("BETTER", 0.05), ("BEST", 0.10)]

        let options: [TierOption] = tierAdders.map { (tier, adder) in
            let markupRate = defaultMarkup + adder
            let markup = baseSubtotal * markupRate
            let taxedBase = baseSubtotal + markup
            let taxAmount = taxedBase * taxRate
            let totalPrice = taxedBase + taxAmount
            let profitMargin = totalPrice == 0 ? 0 : (markup / totalPrice)

            return TierOption(
                id: tier,
                tier: tier,
                totalPrice: roundDecimal(totalPrice),
                profitMargin: NSDecimalNumber(decimal: profitMargin).doubleValue,
                subtotal: roundDecimal(baseSubtotal),
                markup: roundDecimal(markup),
                taxAmount: roundDecimal(taxAmount)
            )
        }

        let selected = options.first(where: { $0.tier == selectedTier }) ?? options[1]

        pricingResult = PricingResult(
            materialCost: roundDecimal(materialCost),
            laborCost: roundDecimal(laborCost),
            overheadCost: roundDecimal(overheadCost),
            selectedTier: selected,
            options: options,
            shoppingList: [
                (label: selectedCoatingSystem?.displayName ?? "Epoxy", quantity: NSDecimalNumber(decimal: Decimal(sqFt) / Decimal(coverageRate) * Decimal(numCoats) * (1 + wasteFactor)).doubleValue, unit: "gal")
            ]
        )

        // Auto-generate line items
        lineItems = [
            EditableLineItem(category: "Material", itemDescription: selectedCoatingSystem?.displayName ?? "Epoxy Coating", quantity: NSDecimalNumber(decimal: Decimal(sqFt) / Decimal(coverageRate) * Decimal(numCoats)).doubleValue, unitPrice: costPerUnit, unit: "gal"),
            EditableLineItem(category: "Labor", itemDescription: "Installation Labor (\(crewCount) crew)", quantity: estimatedHours, unitPrice: laborRate, unit: "hr"),
            EditableLineItem(category: "Mobilization", itemDescription: "Mobilization & Setup", quantity: 1, unitPrice: mobilizationFee, unit: "ea"),
        ]

        // Generate mock AI insights
        generateAIInsights()
    }

    // MARK: - AI Insights (local mock — backend integration ready)

    private func generateAIInsights() {
        let sqFt = totalSqFt

        aiSummary = String(format: NSLocalizedString("ai.summary.fmt", comment: ""),
                           Int(sqFt),
                           selectedCoatingSystem?.displayName ?? NSLocalizedString("coating.custom", comment: ""),
                           surfaceCondition.displayName.lowercased())

        aiRiskFlags = []
        if surfaceCondition == .poor {
            aiRiskFlags.append(NSLocalizedString("ai.risk.poor", comment: ""))
        }
        if sqFt > 2000 {
            aiRiskFlags.append(NSLocalizedString("ai.risk.large", comment: ""))
        }
        if isComplexLayout {
            aiRiskFlags.append(NSLocalizedString("ai.risk.complex", comment: ""))
        }

        aiUpsells = []
        if selectedCoatingSystem != .fullMetallic {
            aiUpsells.append(String(format: NSLocalizedString("ai.upsell.metallic", comment: ""), Int(sqFt * 3), Int(sqFt * 6)))
        }
        aiUpsells.append(String(format: NSLocalizedString("ai.upsell.cove", comment: ""), Int(Double(sqFt) * 0.15 * 8), Int(Double(sqFt) * 0.15 * 12)))
        if sqFt > 500 {
            aiUpsells.append(String(format: NSLocalizedString("ai.upsell.maint", comment: ""), sqFt * 0.5))
        }
    }

    // MARK: - Build & Save Bid

    func buildAndSaveBid(context: ModelContext) -> Bid? {
        let bid = Bid()
        bid.bidNumber = "BID-\(Int.random(in: 10001...99999))"
        bid.title = bidTitle.isEmpty
            ? "\(selectedClient?.displayName ?? "Client") — \(selectedCoatingSystem?.displayName ?? "Epoxy Floor")"
            : bidTitle
        bid.status = .draft
        bid.tier = selectedTier
        bid.coatingSystem = selectedCoatingSystem?.rawValue ?? ""
        bid.totalSqFt = totalSqFt
        bid.client = selectedClient
        bid.measurement = selectedMeasurement

        if let pricing = pricingResult {
            bid.materialCost = pricing.materialCost
            bid.laborCost = pricing.laborCost
            bid.subtotal = pricing.selectedTier.subtotal
            bid.markup = pricing.selectedTier.markup
            bid.taxAmount = pricing.selectedTier.taxAmount
            bid.totalPrice = pricing.selectedTier.totalPrice
            bid.profitMargin = Decimal(pricing.selectedTier.profitMargin)
        }

        bid.scopeNotes = scopeNotes
        bid.executiveSummary = aiSummary
        bid.aiRiskFlags = aiRiskFlags
        bid.aiUpsells = aiUpsells
        bid.validUntil = Calendar.current.date(byAdding: .day, value: validDays, to: Date())

        // Create line items
        for (idx, item) in lineItems.enumerated() {
            let li = BidLineItem()
            li.itemDescription = item.itemDescription
            li.quantity = item.quantity
            li.unitPrice = item.unitPrice
            li.amount = item.amount
            li.sortOrder = idx
            bid.lineItems.append(li)
            context.insert(li)
        }

        context.insert(bid)

        do {
            try context.save()
            return bid
        } catch {
            errorMessage = "Failed to save bid: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Pricing Helpers

    private func materialDefaults(for coating: CoatingSystemOption?) -> (coverageRate: Double, costPerUnit: Decimal, numCoats: Int) {
        switch coating {
        case .singleCoatClear: return (350, 45, 1)
        case .twoCoatFlake:    return (250, 65, 2)
        case .fullMetallic:    return (200, 120, 2)
        case .quartz:          return (250, 75, 2)
        case .polyaspartic:    return (300, 95, 2)
        case .commercialGrade: return (300, 55, 2)
        case .custom, .none:   return (300, 60, 2)
        }
    }

    private func conditionMultiplier(_ condition: SurfaceConditionOption) -> Decimal {
        switch condition {
        case .excellent: return 1.0
        case .good:      return 1.05
        case .fair:      return 1.2
        case .poor:      return 1.35
        }
    }

    private func coatingMultiplier(_ system: CoatingSystemOption?) -> Decimal {
        switch system {
        case .fullMetallic:    return 1.35
        case .commercialGrade: return 1.25
        case .polyaspartic:    return 1.2
        case .quartz:          return 1.15
        default:               return 1.0
        }
    }

    private func prepMultiplier(_ prep: PrepComplexityOption) -> Decimal {
        switch prep {
        case .light:    return 0.9
        case .standard: return 1.0
        case .heavy:    return 1.25
        }
    }

    private func accessMultiplier(_ access: AccessOption) -> Decimal {
        switch access {
        case .easy:      return 0.95
        case .normal:    return 1.0
        case .difficult: return 1.2
        }
    }

    private func roundDecimal(_ value: Decimal) -> Decimal {
        var result = Decimal()
        var mutableValue = value
        NSDecimalRound(&result, &mutableValue, 2, .bankers)
        return result
    }
}
