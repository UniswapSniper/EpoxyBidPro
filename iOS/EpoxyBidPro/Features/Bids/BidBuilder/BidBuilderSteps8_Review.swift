import SwiftUI

// ─── Step 8: Review & Save ───────────────────────────────────────────────────

struct BidBuilderReviewStep: View {

    @ObservedObject var vm: BidBuilderViewModel
    @State private var showScopeEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                stepHeader(
                    icon: "checkmark.seal.fill",
                    title: NSLocalizedString("review.title", comment: ""),
                    subtitle: NSLocalizedString("review.subtitle", comment: "")
                )

                // ── Bid Title ─────────────────────────────────────────────
                VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                    Text(NSLocalizedString("bid.title", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField(
                        "\(vm.selectedClient?.displayName ?? NSLocalizedString("client", comment: "")) — \(vm.selectedCoatingSystem?.displayName ?? NSLocalizedString("epoxy.floor", comment: ""))",
                        text: $vm.bidTitle
                    )
                    .font(.body)
                    .padding(EBPSpacing.sm + 2)
                    .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .ebpHPadding()

                // ── Summary Card ──────────────────────────────────────────
                reviewSummaryCard

                // ── Client Section ────────────────────────────────────────
                reviewSection(title: NSLocalizedString("client", comment: ""), icon: "person.fill") {
                    if let client = vm.selectedClient {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(client.displayName)
                                .font(.subheadline.weight(.medium))
                            if !client.company.isEmpty {
                                Text(client.company)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !client.email.isEmpty {
                                Text(client.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text(NSLocalizedString("no.client.selected", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }

                // ── Measurement Section ───────────────────────────────────
                reviewSection(title: NSLocalizedString("measurement", comment: ""), icon: "ruler.fill") {
                    VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                        Text(String(format: NSLocalizedString("total.sqft.fmt", comment: ""), Int(vm.totalSqFt)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EBPColor.primary)

                        ForEach(vm.areaBreakdown, id: \.name) { area in
                            HStack {
                                Text(area.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: NSLocalizedString("total.sqft.fmt", comment: ""), Int(area.sqFt)))
                                    .font(.caption.weight(.medium))
                            }
                        }
                    }
                }

                // ── Coating & Prep ────────────────────────────────────────
                reviewSection(title: NSLocalizedString("coating.prep", comment: ""), icon: "paintbrush.fill") {
                    VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                        labeledField(NSLocalizedString("coating.system", comment: ""), vm.selectedCoatingSystem?.displayName ?? "—")
                        labeledField(NSLocalizedString("surface.condition", comment: ""), vm.surfaceCondition.displayName)
                        labeledField(NSLocalizedString("prep.complexity", comment: ""), vm.prepComplexity.displayName)
                        labeledField(NSLocalizedString("access.difficulty", comment: ""), vm.accessDifficulty.displayName)
                        if vm.isComplexLayout {
                            labeledField(NSLocalizedString("complex.layout", comment: ""), NSLocalizedString("yes.waste", comment: ""))
                        }
                        labeledField(NSLocalizedString("crew.size", comment: ""), "\(vm.crewCount)")
                        labeledField(NSLocalizedString("est.hours", comment: ""), String(format: NSLocalizedString("per.hours", comment: "%.1f hrs"), vm.estimatedHours))
                    }
                }

                // ── Pricing ───────────────────────────────────────────────
                if let pricing = vm.pricingResult {
                    reviewSection(title: String(format: NSLocalizedString("pricing.tier.fmt", comment: ""), vm.selectedTier), icon: "dollarsign.circle.fill") {
                        VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                            pricingRow(NSLocalizedString("materials", comment: ""), pricing.materialCost)
                            pricingRow(NSLocalizedString("labor", comment: ""), pricing.laborCost)
                            pricingRow(NSLocalizedString("overhead", comment: ""), pricing.overheadCost)
                            pricingRow(NSLocalizedString("markup", comment: ""), pricing.selectedTier.markup)
                            pricingRow(NSLocalizedString("tax", comment: ""), pricing.selectedTier.taxAmount)
                            Divider()
                            HStack {
                                Text(NSLocalizedString("total", comment: ""))
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Text(formatCurrency(pricing.selectedTier.totalPrice))
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(EBPColor.primary)
                            }
                            HStack {
                                Text(NSLocalizedString("profit.margin", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(pricing.selectedTier.profitMargin * 100))%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(EBPColor.success)
                            }
                        }
                    }
                }

                // ── Line Items Count ──────────────────────────────────────
                reviewSection(title: NSLocalizedString("line.items", comment: ""), icon: "list.bullet.rectangle") {
                    HStack {
                        Text(String(format: NSLocalizedString("items.fmt", comment: ""), vm.lineItems.count))
                            .font(.subheadline)
                        Spacer()
                        let total = vm.lineItems.reduce(Decimal(0)) { $0 + $1.amount }
                        Text(total, format: .currency(code: "USD"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EBPColor.primary)
                    }
                }

                // ── AI Insights Summary ───────────────────────────────────
                if !vm.aiRiskFlags.isEmpty || !vm.aiUpsells.isEmpty {
                    reviewSection(title: NSLocalizedString("ai.insights", comment: ""), icon: "brain") {
                        VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                            if !vm.aiRiskFlags.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(EBPColor.warning)
                                    Text(String(format: NSLocalizedString("risk.flags.fmt", comment: ""), vm.aiRiskFlags.count))
                                        .font(.caption.weight(.medium))
                                }
                            }
                            if !vm.aiUpsells.isEmpty {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(EBPColor.success)
                                    Text(String(format: NSLocalizedString("upsell.opps.fmt", comment: ""), vm.aiUpsells.count, ""))
                                        .font(.caption.weight(.medium))
                                }
                            }
                        }
                    }
                }

                // ── Scope Notes ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                    HStack {
                        Text(NSLocalizedString("scope.notes", comment: ""))
                            .font(.headline)
                        Spacer()
                        Button(NSLocalizedString("edit", comment: "")) { showScopeEditor.toggle() }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(EBPColor.primary)
                    }

                    if vm.scopeNotes.isEmpty {
                        Text(NSLocalizedString("no.scope.notes", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        Text(vm.scopeNotes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
                .padding(EBPSpacing.md)
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpShadowSubtle()
                .ebpHPadding()

                // ── Valid Until ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                    Text(NSLocalizedString("valid.for", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker(NSLocalizedString("valid.for", comment: ""), selection: $vm.validDays) {
                        Text(String(format: NSLocalizedString("days.fmt", comment: ""), 14)).tag(14)
                        Text(String(format: NSLocalizedString("days.fmt", comment: ""), 30)).tag(30)
                        Text(String(format: NSLocalizedString("days.fmt", comment: ""), 60)).tag(60)
                        Text(String(format: NSLocalizedString("days.fmt", comment: ""), 90)).tag(90)
                    }
                    .pickerStyle(.segmented)
                }
                .ebpHPadding()

                Spacer(minLength: 80)
            }
            .padding(.vertical, EBPSpacing.md)
        }
        .sheet(isPresented: $showScopeEditor) {
            scopeEditorSheet
        }
    }

    // MARK: - Summary Card

    private var reviewSummaryCard: some View {
        let pricing = vm.pricingResult
        return VStack(spacing: EBPSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                if let pricing {
                    Text(formatCurrency(pricing.selectedTier.totalPrice))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("—")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                EBPPillTag(text: vm.selectedTier, color: .white)
            }

            HStack(spacing: EBPSpacing.md) {
                Label("\(Int(vm.totalSqFt)) sq ft", systemImage: "square.dashed")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                if let coating = vm.selectedCoatingSystem {
                    Label(coating.displayName, systemImage: coating.icon)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer()
            }

            if let client = vm.selectedClient {
                HStack {
                    Label(client.displayName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
            }
        }
        .padding(EBPSpacing.lg)
        .background(EBPColor.heroGradient, in: RoundedRectangle(cornerRadius: EBPRadius.lg))
        .ebpShadowStrong()
        .ebpHPadding()
    }

    // MARK: - Helpers

    private func reviewSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.sm) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EBPColor.primary)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
        .ebpHPadding()
    }

    private func labeledField(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }

    private func pricingRow(_ label: String, _ value: Decimal) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatCurrency(value))
                .font(.subheadline.monospacedDigit())
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    // MARK: - Scope Editor Sheet

    private var scopeEditorSheet: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $vm.scopeNotes)
                    .font(.body)
                    .padding(EBPSpacing.md)
            }
            .navigationTitle(NSLocalizedString("scope.notes", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("done", comment: "")) { showScopeEditor = false }
                }
            }
        }
    }
}
