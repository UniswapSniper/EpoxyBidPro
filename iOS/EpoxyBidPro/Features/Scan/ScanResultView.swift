// ═══════════════════════════════════════════════════════════════════════════════
// ScanResultView.swift
// Post-scan results with polygon map, wall dimensions, inline coating picker,
// real-time pricing, Quick Bid one-tap, and full BidBuilder navigation.
// ═══════════════════════════════════════════════════════════════════════════════

import SwiftUI
import SwiftData
import simd

struct ScanResultView: View {

    // ── Inputs from ScanView ────────────────────────────────────────────────

    let totalSqFt: Double
    let perimeterFt: Double
    let wallLengthsFt: [Double]
    let cornerCount: Int
    let polygonVertices: [SIMD2<Float>]
    let polygonJson: String

    // ── Environment ─────────────────────────────────────────────────────────

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // ── Local State ─────────────────────────────────────────────────────────

    @State private var areaName = "Garage Floor"
    @State private var editedSqFt: Double = 0
    @State private var savedMeasurement: Measurement?
    @State private var showSuccessBanner = false
    @State private var navigateToBid = false
    @State private var navigateToCustomize = false

    // ── Coating & Pricing State ─────────────────────────────────────────────

    @State private var selectedCoating: BidBuilderViewModel.CoatingSystemOption? = nil
    @State private var selectedTier: String = "BETTER"
    @State private var calculatedPricing: ScanQuickPricing? = nil
    @State private var isCalculating = false
    @State private var showDimensions = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                polygonMapSection
                dimensionsToggle
                coatingPickerSection
                if let pricing = calculatedPricing {
                    pricingResultSection(pricing)
                }
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(EBPColor.canvas.ignoresSafeArea())
        .navigationTitle("Scan Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToBid) {
            if let m = savedMeasurement {
                BidBuilderView(initialMeasurement: m)
            }
        }
        .navigationDestination(isPresented: $navigateToCustomize) {
            if let m = savedMeasurement {
                BidBuilderView(initialMeasurement: m, initialCoating: selectedCoating)
            }
        }
        .onAppear { editedSqFt = totalSqFt }
        .onChange(of: selectedCoating) { _, _ in recalculatePricing() }
        .onChange(of: selectedTier)    { _, _ in recalculatePricing() }
        .onChange(of: editedSqFt)     { _, _ in recalculatePricing() }
        .overlay(alignment: .top) {
            if showSuccessBanner {
                successBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                // Area
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", editedSqFt))
                        .font(EBPFont.stat)
                        .foregroundStyle(EBPColor.accent)
                    Text("sq ft")
                        .font(EBPFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 44)

                // Perimeter
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", perimeterFt))
                        .font(EBPFont.statSm)
                        .foregroundStyle(.primary)
                    Text("ft perimeter")
                        .font(EBPFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 44)

                // Corners
                VStack(spacing: 2) {
                    Text("\(cornerCount)")
                        .font(EBPFont.statSm)
                        .foregroundStyle(.primary)
                    Text("corners")
                        .font(EBPFont.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Editable area name
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(EBPColor.accent)
                    .font(.caption)
                TextField("Area Name", text: $areaName)
                    .font(EBPFont.callout)
            }
            .padding(12)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.lg))
        .ebpShadowSubtle()
    }

    // MARK: - Polygon Map

    private var polygonMapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EBPSectionHeader(title: "Floor Plan")

            PolygonMapView(
                vertices: polygonVertices,
                wallLengthsFt: wallLengthsFt
            )
            .frame(height: 200)
            .padding(12)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            .ebpShadowSubtle()
        }
    }

    // MARK: - Wall Dimensions (Collapsible)

    private var dimensionsToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(EBPAnimation.snappy) { showDimensions.toggle() }
            } label: {
                HStack {
                    Image(systemName: "ruler")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EBPColor.accent)
                    Text("Wall Dimensions (\(wallLengthsFt.count))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: showDimensions ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpShadowSubtle()
            }
            .buttonStyle(.plain)

            if showDimensions {
                VStack(spacing: 4) {
                    ForEach(Array(wallLengthsFt.enumerated()), id: \.offset) { index, length in
                        HStack {
                            Text("Wall \(index + 1)")
                                .font(EBPFont.callout)
                            Spacer()
                            Text(String(format: "%.1f ft", length))
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(EBPColor.accent)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(
                            index.isMultiple(of: 2)
                                ? EBPColor.surface
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                }
                .padding(10)
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpShadowSubtle()
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Coating Picker (Inline)

    private var coatingPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EBPSectionHeader(title: "Choose Coating")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BidBuilderViewModel.CoatingSystemOption.allCases) { option in
                        coatingChip(option)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func coatingChip(_ option: BidBuilderViewModel.CoatingSystemOption) -> some View {
        let isSelected = selectedCoating == option
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(EBPAnimation.snappy) {
                selectedCoating = isSelected ? nil : option
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: EBPRadius.sm)
                        .fill(option.tintColor.opacity(isSelected ? 0.25 : 0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: option.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(option.tintColor)
                }

                Text(option.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(option.priceRange)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(option.tintColor)
            }
            .frame(width: 80)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .fill(EBPColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .strokeBorder(isSelected ? option.tintColor : Color.clear, lineWidth: 2)
            )
            .ebpShadowSubtle()
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pricing Result

    private func pricingResultSection(_ pricing: ScanQuickPricing) -> some View {
        VStack(spacing: 14) {
            // Tier selector
            HStack(spacing: 8) {
                ForEach(pricing.tiers) { tier in
                    let isSelected = selectedTier == tier.id
                    Button {
                        AppHaptics.trigger(.medium)
                        withAnimation(EBPAnimation.snappy) { selectedTier = tier.id }
                    } label: {
                        VStack(spacing: 4) {
                            Text(tier.id)
                                .font(.caption2.weight(.black))
                                .tracking(1)
                                .foregroundStyle(isSelected ? .white : tierColor(tier.id))

                            Text(formatCurrency(tier.totalPrice))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text("\(Int(tier.profitMargin * 100))% margin")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: EBPRadius.md)
                                .fill(isSelected ? tierGradient(tier.id) : AnyShapeStyle(EBPColor.surface))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EBPRadius.md)
                                .strokeBorder(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Price hero card
            if let selected = pricing.tiers.first(where: { $0.id == selectedTier }) {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(formatCurrency(selected.totalPrice))
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        EBPPillTag(text: selected.id, color: .white)
                    }

                    HStack {
                        Label("\(Int(editedSqFt)) sq ft", systemImage: "square.dashed")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        if editedSqFt > 0 {
                            let perSqFt = selected.totalPrice / Decimal(editedSqFt)
                            Text("$\(NSDecimalNumber(decimal: perSqFt).doubleValue, specifier: "%.2f") / sq ft")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.15))

                    HStack(spacing: 16) {
                        miniBreakdown("Materials", value: pricing.materialCost)
                        miniBreakdown("Labor", value: pricing.laborCost)
                        miniBreakdown("Overhead", value: pricing.overheadCost)
                    }
                }
                .padding(16)
                .background(tierGradient(selected.id), in: RoundedRectangle(cornerRadius: EBPRadius.lg))
                .ebpShadowStrong()
            }
        }
    }

    private func miniBreakdown(_ label: String, value: Decimal) -> some View {
        VStack(spacing: 2) {
            Text(formatCurrency(value))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Quick Bid — one tap, saves draft immediately
            if selectedCoating != nil, calculatedPricing != nil {
                Button { quickBid() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Quick Bid — Save Draft")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(EBPColor.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                    .shadow(color: EBPColor.accent.opacity(0.4), radius: 12, y: 4)
                }

                Button { customizeBid() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Customize Bid")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(EBPColor.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(EBPColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: EBPRadius.md)
                            .stroke(EBPColor.accent.opacity(0.25), lineWidth: 1)
                    )
                }
            } else {
                // No coating selected yet — show build bid
                Button { saveAndBuildBid() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                        Text("Build Bid")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(EBPColor.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                    .shadow(color: EBPColor.accent.opacity(0.3), radius: 10, y: 4)
                }
            }

            // Save Only
            Button { saveOnly() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Measurement Only")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Quick Pricing Engine

    private func recalculatePricing() {
        guard let coating = selectedCoating, editedSqFt > 0 else {
            calculatedPricing = nil
            return
        }
        isCalculating = true

        let sqFt = editedSqFt
        let (coverageRate, costPerUnit, numCoats) = materialDefaults(for: coating)
        let wasteFactor: Decimal = 0.10
        let laborRate: Decimal = 55
        let overheadRate: Decimal = 0.15
        let mobilizationFee: Decimal = 150
        let defaultMarkup: Decimal = 0.25
        let taxRate: Decimal = 0.08

        let rawMaterial = Decimal(sqFt) / Decimal(coverageRate) * Decimal(numCoats) * costPerUnit
        let materialCost = rawMaterial * (1 + wasteFactor)

        let baseHours = ceil(sqFt / 200) * 2
        let condMult: Decimal = 1.05   // Good (default assumption)
        let coatMult = coatingMultiplier(coating)
        let adjustedHours = Decimal(baseHours) * condMult * coatMult
        let laborCost = adjustedHours * laborRate * 2 // 2 crew default

        let overheadCost = (materialCost + laborCost) * overheadRate
        let baseSubtotal = materialCost + laborCost + overheadCost + mobilizationFee

        let tierAdders: [(String, Decimal)] = [("GOOD", 0), ("BETTER", 0.05), ("BEST", 0.10)]
        let tiers: [ScanQuickTier] = tierAdders.map { (tier, adder) in
            let markupRate = defaultMarkup + adder
            let markup = baseSubtotal * markupRate
            let taxedBase = baseSubtotal + markup
            let taxAmount = taxedBase * taxRate
            let totalPrice = taxedBase + taxAmount
            let profitMargin = totalPrice == 0 ? 0 : (markup / totalPrice)
            return ScanQuickTier(
                id: tier,
                totalPrice: roundDecimal(totalPrice),
                profitMargin: NSDecimalNumber(decimal: profitMargin).doubleValue,
                subtotal: roundDecimal(baseSubtotal),
                markup: roundDecimal(markup),
                taxAmount: roundDecimal(taxAmount)
            )
        }

        calculatedPricing = ScanQuickPricing(
            materialCost: roundDecimal(materialCost),
            laborCost: roundDecimal(laborCost),
            overheadCost: roundDecimal(overheadCost),
            tiers: tiers
        )
        isCalculating = false
    }

    // MARK: - Save Logic

    private func quickBid() {
        guard let coating = selectedCoating, let pricing = calculatedPricing else { return }
        let measurement = persistMeasurement()

        let bid = Bid()
        bid.bidNumber = "BID-\(Int.random(in: 10001...99999))"
        bid.title = "\(areaName) — \(coating.displayName)"
        bid.status = "DRAFT"
        bid.tier = selectedTier
        bid.coatingSystem = coating.rawValue
        bid.totalSqFt = editedSqFt
        bid.measurement = measurement

        if let tier = pricing.tiers.first(where: { $0.id == selectedTier }) {
            bid.materialCost = pricing.materialCost
            bid.laborCost = pricing.laborCost
            bid.subtotal = tier.subtotal
            bid.markup = tier.markup
            bid.taxAmount = tier.taxAmount
            bid.totalPrice = tier.totalPrice
            bid.profitMargin = Decimal(tier.profitMargin)
        }

        bid.validUntil = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        // Auto-generate line items
        let (coverageRate, costPerUnit, numCoats) = materialDefaults(for: coating)
        let matQty = editedSqFt / coverageRate * Double(numCoats)
        let hours = ceil(editedSqFt / 200) * 2

        let materialLine = BidLineItem()
        materialLine.itemDescription = coating.displayName
        materialLine.quantity = matQty
        materialLine.unitPrice = costPerUnit
        materialLine.amount = Decimal(matQty) * costPerUnit
        materialLine.sortOrder = 0
        bid.lineItems.append(materialLine)
        modelContext.insert(materialLine)

        let laborLine = BidLineItem()
        laborLine.itemDescription = "Installation Labor (2 crew)"
        laborLine.quantity = hours
        laborLine.unitPrice = 55
        laborLine.amount = Decimal(hours) * 55
        laborLine.sortOrder = 1
        bid.lineItems.append(laborLine)
        modelContext.insert(laborLine)

        let mobileLine = BidLineItem()
        mobileLine.itemDescription = "Mobilization & Setup"
        mobileLine.quantity = 1
        mobileLine.unitPrice = 150
        mobileLine.amount = 150
        mobileLine.sortOrder = 2
        bid.lineItems.append(mobileLine)
        modelContext.insert(mobileLine)

        modelContext.insert(bid)
        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showSuccessBanner(message: "Draft bid saved!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    private func customizeBid() {
        let measurement = persistMeasurement()
        savedMeasurement = measurement
        showSuccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            navigateToCustomize = true
        }
    }

    private func saveAndBuildBid() {
        let measurement = persistMeasurement()
        savedMeasurement = measurement
        showSuccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            navigateToBid = true
        }
    }

    private func saveOnly() {
        _ = persistMeasurement()
        showSuccess()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    private func persistMeasurement() -> Measurement {
        let measurement = Measurement(
            label: areaName,
            notes: "Perimeter scan – \(cornerCount) corners",
            totalSqFt: editedSqFt,
            scanDate: Date()
        )
        modelContext.insert(measurement)

        let area = Area(
            name: areaName,
            squareFeet: editedSqFt,
            polygonJson: polygonJson,
            sortOrder: 0,
            capturedAt: Date()
        )
        area.measurement = measurement
        modelContext.insert(area)

        try? modelContext.save()
        return measurement
    }

    private func showSuccess() {
        showSuccessBanner(message: "Measurement saved!")
    }

    private func showSuccessBanner(message: String) {
        successMessage = message
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            showSuccessBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSuccessBanner = false }
        }
    }

    @State private var successMessage = "Measurement saved!"

    // MARK: - Success Banner

    private var successBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(EBPColor.success)
            Text(successMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(EBPColor.success.opacity(0.2))
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 8)
    }

    // MARK: - Pricing Helpers

    private func materialDefaults(for coating: BidBuilderViewModel.CoatingSystemOption) -> (coverageRate: Double, costPerUnit: Decimal, numCoats: Int) {
        switch coating {
        case .singleCoatClear: return (350, 45, 1)
        case .twoCoatFlake:    return (250, 65, 2)
        case .fullMetallic:    return (200, 120, 2)
        case .quartz:          return (250, 75, 2)
        case .polyaspartic:    return (300, 95, 2)
        case .commercialGrade: return (300, 55, 2)
        case .custom:          return (300, 60, 2)
        }
    }

    private func coatingMultiplier(_ system: BidBuilderViewModel.CoatingSystemOption) -> Decimal {
        switch system {
        case .fullMetallic:    return 1.35
        case .commercialGrade: return 1.25
        case .polyaspartic:    return 1.2
        case .quartz:          return 1.15
        default:               return 1.0
        }
    }

    private func roundDecimal(_ value: Decimal) -> Decimal {
        var result = Decimal()
        var mutableValue = value
        NSDecimalRound(&result, &mutableValue, 2, .bankers)
        return result
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "GOOD":   return .blue
        case "BETTER": return EBPColor.accent
        case "BEST":   return EBPColor.gold
        default:       return .secondary
        }
    }

    private func tierGradient(_ tier: String) -> AnyShapeStyle {
        switch tier {
        case "GOOD":
            return AnyShapeStyle(LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case "BETTER":
            return AnyShapeStyle(EBPColor.heroGradient)
        case "BEST":
            return AnyShapeStyle(LinearGradient(colors: [EBPColor.gold, EBPColor.gold.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(EBPColor.primaryGradient)
        }
    }
}

// MARK: - Quick Pricing Models

struct ScanQuickTier: Identifiable {
    let id: String
    let totalPrice: Decimal
    let profitMargin: Double
    let subtotal: Decimal
    let markup: Decimal
    let taxAmount: Decimal
}

struct ScanQuickPricing {
    let materialCost: Decimal
    let laborCost: Decimal
    let overheadCost: Decimal
    let tiers: [ScanQuickTier]
}

// MARK: - Polygon Map View (2-D top-down)

struct PolygonMapView: View {

    let vertices: [SIMD2<Float>]
    let wallLengthsFt: [Double]

    var body: some View {
        GeometryReader { geo in
            let scaled = scaleToFit(vertices: vertices, in: geo.size, padding: 44)

            Canvas { context, _ in
                guard scaled.count >= 3 else { return }

                // Filled polygon
                var fillPath = Path()
                fillPath.move(to: scaled[0])
                for pt in scaled.dropFirst() { fillPath.addLine(to: pt) }
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(EBPColor.accent.opacity(0.12)))
                context.stroke(fillPath, with: .color(EBPColor.accent), lineWidth: 2.5)

                // Corner dots
                for pt in scaled {
                    let r: CGFloat = 4.5
                    let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(EBPColor.accent))
                }
            }

            // Wall length labels
            ForEach(Array(wallLengthsFt.enumerated()), id: \.offset) { idx, length in
                if idx < scaled.count {
                    let from = scaled[idx]
                    let to   = scaled[(idx + 1) % scaled.count]
                    let mid  = CGPoint(x: (from.x + to.x) / 2,
                                       y: (from.y + to.y) / 2)

                    Text(String(format: "%.1f'", length))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(EBPColor.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(EBPColor.surface.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .position(mid)
                }
            }
        }
    }

    // Scale + center polygon into the available rect.
    private func scaleToFit(vertices: [SIMD2<Float>],
                            in size: CGSize,
                            padding: CGFloat) -> [CGPoint] {
        guard !vertices.isEmpty else { return [] }

        let xs = vertices.map { CGFloat($0.x) }
        let ys = vertices.map { CGFloat($0.y) }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!

        let dw = maxX - minX
        let dh = maxY - minY
        let aw = size.width  - 2 * padding
        let ah = size.height - 2 * padding

        let scale: CGFloat
        if dw < 0.001 && dh < 0.001 { scale = 1 }
        else if dw < 0.001          { scale = ah / dh }
        else if dh < 0.001          { scale = aw / dw }
        else                        { scale = min(aw / dw, ah / dh) }

        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2

        return vertices.map { v in
            CGPoint(
                x: (CGFloat(v.x) - cx) * scale + size.width  / 2,
                y: (CGFloat(v.y) - cy) * scale + size.height / 2
            )
        }
    }
}
