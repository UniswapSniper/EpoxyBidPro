import SwiftUI

// ─── Step 5: Pricing ─────────────────────────────────────────────────────────

struct BidBuilderPricingStep: View {

    @ObservedObject var vm: BidBuilderViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                stepHeader(
                    icon: "dollarsign.circle.fill",
                    title: NSLocalizedString("pricing.preview", comment: ""),
                    subtitle: NSLocalizedString("pricing.subtitle", comment: "")
                )

                if let pricing = vm.pricingResult {
                    // ── Tier Selector ──────────────────────────────────────
                    tierSelector(pricing)

                    // ── Selected Tier Price Card ──────────────────────────
                    selectedPriceCard(pricing)

                    // ── Cost Breakdown ─────────────────────────────────────
                    costBreakdown(pricing)

                    // ── Margin Indicator ───────────────────────────────────
                    marginIndicator(pricing)

                    // ── Shopping List ──────────────────────────────────────
                    if !pricing.shoppingList.isEmpty {
                        shoppingListSection(pricing)
                    }

                } else {
                    VStack(spacing: EBPSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(NSLocalizedString("calculating", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EBPSpacing.xxxl)
                }
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    // MARK: - Tier Selector

    private func tierSelector(_ pricing: BidBuilderViewModel.PricingResult) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            ForEach(pricing.options) { option in
                let isSelected = vm.selectedTier == option.tier
                Button {
                    AppHaptics.trigger(.medium)
                    withAnimation(EBPAnimation.snappy) {
                        vm.selectedTier = option.tier
                        Task { await vm.calculatePricing() }
                    }
                } label: {
                    VStack(spacing: EBPSpacing.xs) {
                        Text(option.tier)
                            .font(.caption2.weight(.black))
                            .tracking(1)
                            .foregroundStyle(isSelected ? .white : tierColor(option.tier))

                        Text(formatCurrency(option.totalPrice))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(String(format: NSLocalizedString("margin.label", comment: ""), Int(option.profitMargin * 100)))
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EBPSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: EBPRadius.md)
                            .fill(isSelected ? tierGradient(option.tier) : AnyShapeStyle(EBPColor.surface))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EBPRadius.md)
                            .strokeBorder(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                    )
                    .if(isSelected) { $0.ebpShadowMedium() }
                }
                .buttonStyle(.plain)
            }
        }
        .ebpHPadding()
    }

    // MARK: - Selected Price Card

    private func selectedPriceCard(_ pricing: BidBuilderViewModel.PricingResult) -> some View {
        let tier = pricing.selectedTier
        return VStack(spacing: EBPSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(formatCurrency(tier.totalPrice))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                EBPPillTag(text: tier.tier, color: .white)
            }

            HStack {
                Label("\(Int(vm.totalSqFt)) sq ft", systemImage: "square.dashed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(perSqFtLabel(total: tier.totalPrice, sqFt: vm.totalSqFt))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(EBPSpacing.lg)
        .background(tierGradient(tier.tier), in: RoundedRectangle(cornerRadius: EBPRadius.lg))
        .ebpShadowStrong()
        .ebpHPadding()
    }

    // MARK: - Cost Breakdown

    private func costBreakdown(_ pricing: BidBuilderViewModel.PricingResult) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text(NSLocalizedString("cost.breakdown", comment: ""))
                .font(.headline)
                .ebpHPadding()

            VStack(spacing: 0) {
                breakdownRow(NSLocalizedString("materials", comment: ""), value: pricing.materialCost, icon: "cube.fill", tint: .blue)
                Divider().padding(.leading, 44)
                breakdownRow(NSLocalizedString("labor", comment: ""), value: pricing.laborCost, icon: "person.2.fill", tint: .orange)
                Divider().padding(.leading, 44)
                breakdownRow(NSLocalizedString("overhead", comment: ""), value: pricing.overheadCost, icon: "building.fill", tint: .purple)
                Divider().padding(.leading, 44)
                breakdownRow(NSLocalizedString("markup", comment: ""), value: pricing.selectedTier.markup, icon: "arrow.up.right", tint: EBPColor.success)
                Divider().padding(.leading, 44)
                breakdownRow(NSLocalizedString("tax", comment: ""), value: pricing.selectedTier.taxAmount, icon: "doc.text", tint: .secondary)
                Divider()
                HStack {
                    Text(NSLocalizedString("total", comment: ""))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text(formatCurrency(pricing.selectedTier.totalPrice))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(EBPColor.primary)
                }
                .padding(.horizontal, EBPSpacing.md)
                .padding(.vertical, 10)
            }
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            .ebpShadowSubtle()
            .ebpHPadding()
        }
    }

    private func breakdownRow(_ label: String, value: Decimal, icon: String, tint: Color) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(formatCurrency(value))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.vertical, 10)
    }

    // MARK: - Margin Indicator

    private func marginIndicator(_ pricing: BidBuilderViewModel.PricingResult) -> some View {
        let margin = pricing.selectedTier.profitMargin
        let marginPct = Int(margin * 100)
        let barColor: Color = marginPct >= 25 ? EBPColor.success : (marginPct >= 15 ? EBPColor.warning : EBPColor.danger)

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Label(NSLocalizedString("profit.margin", comment: ""), systemImage: "chart.pie.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(marginPct)%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * min(CGFloat(margin), 0.5) * 2, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text(NSLocalizedString("low", comment: ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(NSLocalizedString("healthy", comment: ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(NSLocalizedString("premium", comment: ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
        .ebpHPadding()
    }

    // MARK: - Shopping List

    private func shoppingListSection(_ pricing: BidBuilderViewModel.PricingResult) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Label(NSLocalizedString("shopping.list", comment: ""), systemImage: "cart.fill")
                    .font(.headline)
                Spacer()
                Text(NSLocalizedString("auto.generated", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .ebpHPadding()

            VStack(spacing: 0) {
                ForEach(Array(pricing.shoppingList.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Image(systemName: "cube")
                            .font(.caption)
                            .foregroundStyle(EBPColor.primary)
                        Text(item.label)
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f %@", item.quantity, item.unit))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EBPColor.primary)
                    }
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.vertical, 10)
                }
            }
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            .ebpShadowSubtle()
            .ebpHPadding()
        }
    }

    // MARK: - Helpers

    private func tierColor(_ tier: String) -> Color {
        switch tier {
        case "GOOD":   return .blue
        case "BETTER": return EBPColor.primary
        case "BEST":   return EBPColor.gold
        default:       return EBPColor.primary
        }
    }

    private func tierGradient(_ tier: String) -> AnyShapeStyle {
        switch tier {
        case "GOOD":
            return AnyShapeStyle(LinearGradient(colors: [.blue, Color(red: 0.2, green: 0.5, blue: 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case "BEST":
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.7, green: 0.5, blue: 0.1), EBPColor.gold], startPoint: .topLeading, endPoint: .bottomTrailing))
        default:
            return AnyShapeStyle(EBPColor.primaryGradient)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func perSqFtLabel(total: Decimal, sqFt: Double) -> String {
        guard sqFt > 0 else { return "" }
        let perSqFtValue = NSDecimalNumber(decimal: total).doubleValue / sqFt
        return String(format: NSLocalizedString("per.sqft", comment: ""), perSqFtValue)
    }
}
