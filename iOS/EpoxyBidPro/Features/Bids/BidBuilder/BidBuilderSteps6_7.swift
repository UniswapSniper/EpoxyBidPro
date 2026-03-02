import SwiftUI

// ─── Step 6: AI Insights ─────────────────────────────────────────────────────

struct BidBuilderAIStep: View {

    @ObservedObject var vm: BidBuilderViewModel
    @State private var expandedRisks = true
    @State private var expandedUpsells = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                stepHeader(
                    icon: "brain",
                    title: NSLocalizedString("ai.insights", comment: ""),
                    subtitle: NSLocalizedString("ai.insights.subtitle", comment: "")
                )

                // ── AI Summary ────────────────────────────────────────────
                if !vm.aiSummary.isEmpty {
                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        HStack(spacing: EBPSpacing.sm) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(EBPColor.accent)
                            Text(NSLocalizedString("ai.analysis", comment: ""))
                                .font(.headline)
                        }
                        Text(vm.aiSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(EBPSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: EBPRadius.md)
                            .fill(EBPColor.accent.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: EBPRadius.md)
                            .strokeBorder(EBPColor.accent.opacity(0.15), lineWidth: 1)
                    )
                    .ebpHPadding()
                }

                // ── Risk Flags ────────────────────────────────────────────
                if !vm.aiRiskFlags.isEmpty {
                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        Button {
                            withAnimation { expandedRisks.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(EBPColor.warning)
                                Text(NSLocalizedString("risk.flags", comment: ""))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                EBPBadge(text: "\(vm.aiRiskFlags.count)", color: EBPColor.warning)
                                Image(systemName: expandedRisks ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if expandedRisks {
                            ForEach(vm.aiRiskFlags, id: \.self) { flag in
                                HStack(alignment: .top, spacing: EBPSpacing.sm) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.caption)
                                        .foregroundStyle(EBPColor.warning)
                                        .padding(.top, 2)
                                    Text(flag)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineSpacing(3)
                                }
                                .padding(EBPSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(EBPColor.warning.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                            }
                        }
                    }
                    .padding(EBPSpacing.md)
                    .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                    .ebpShadowSubtle()
                    .ebpHPadding()
                }

                // ── Upsell Opportunities ──────────────────────────────────
                if !vm.aiUpsells.isEmpty {
                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        Button {
                            withAnimation { expandedUpsells.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(EBPColor.success)
                                Text(NSLocalizedString("upsell.opps", comment: ""))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                EBPBadge(text: "\(vm.aiUpsells.count)", color: EBPColor.success)
                                Image(systemName: expandedUpsells ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if expandedUpsells {
                            ForEach(vm.aiUpsells, id: \.self) { upsell in
                                HStack(alignment: .top, spacing: EBPSpacing.sm) {
                                    Image(systemName: "sparkle")
                                        .font(.caption)
                                        .foregroundStyle(EBPColor.success)
                                        .padding(.top, 2)
                                    Text(upsell)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineSpacing(3)
                                }
                                .padding(EBPSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(EBPColor.success.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                            }
                        }
                    }
                    .padding(EBPSpacing.md)
                    .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                    .ebpShadowSubtle()
                    .ebpHPadding()
                }

                // ── Empty state ───────────────────────────────────────────
                if vm.aiRiskFlags.isEmpty && vm.aiUpsells.isEmpty && vm.aiSummary.isEmpty {
                    VStack(spacing: EBPSpacing.md) {
                        Image(systemName: "brain")
                            .font(.system(size: 48))
                            .foregroundStyle(EBPColor.primary.opacity(0.3))
                        Text(NSLocalizedString("no.ai.insights", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("ai.not.connected", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, EBPSpacing.xl)
                }

                // ── Info footer ───────────────────────────────────────────
                HStack(spacing: EBPSpacing.sm) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("ai.disclaimer", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .ebpHPadding()
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }
}

// ─── Step 7: Line Items ──────────────────────────────────────────────────────

struct BidBuilderLineItemsStep: View {

    @ObservedObject var vm: BidBuilderViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                stepHeader(
                    icon: "list.bullet.rectangle",
                    title: NSLocalizedString("line.items", comment: ""),
                    subtitle: NSLocalizedString("line.items.subtitle", comment: "")
                )

                // ── Line Items ────────────────────────────────────────────
                VStack(spacing: 0) {
                    ForEach($vm.lineItems) { $item in
                        lineItemCard($item: $item)

                        if item.id != vm.lineItems.last?.id {
                            Divider().padding(.leading, EBPSpacing.md)
                        }
                    }
                }
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpShadowSubtle()
                .ebpHPadding()

                // ── Add Item Button ───────────────────────────────────────
                Button {
                    withAnimation {
                        vm.lineItems.append(BidBuilderViewModel.EditableLineItem(
                            category: "Other",
                            itemDescription: "",
                            quantity: 1,
                            unitPrice: 0,
                            unit: "ea"
                        ))
                    }
                } label: {
                    Label(NSLocalizedString("add.line.item", comment: ""), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(EBPColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(EBPColor.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: EBPRadius.md)
                                .strokeBorder(EBPColor.primary.opacity(0.2), lineWidth: 1, antialiased: true)
                        )
                }
                .ebpHPadding()

                // ── Total ─────────────────────────────────────────────────
                let lineTotal = vm.lineItems.reduce(Decimal(0)) { $0 + $1.amount }
                HStack {
                    Text(NSLocalizedString("line.items.total", comment: ""))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(lineTotal, format: .currency(code: "USD"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EBPColor.primary)
                }
                .padding(EBPSpacing.md)
                .background(EBPColor.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpHPadding()
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    // MARK: - Line Item Card

    private func lineItemCard(@Binding item: BidBuilderViewModel.EditableLineItem) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                EBPPillTag(text: item.category, color: categoryColor(item.category))
                Spacer()
                Button {
                    withAnimation {
                        vm.lineItems.removeAll { $0.id == item.id }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }

            TextField(NSLocalizedString("description", comment: ""), text: $item.itemDescription)
                .font(.subheadline)

            HStack(spacing: EBPSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("qty", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("0", value: $item.quantity, format: .number)
                        .font(.subheadline.monospacedDigit())
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("unit.price", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("$0", value: $item.unitPrice, format: .currency(code: "USD"))
                        .font(.subheadline.monospacedDigit())
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("unit", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    TextField("ea", text: $item.unit)
                        .font(.subheadline)
                        .frame(width: 40)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(NSLocalizedString("amount", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.amount, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(EBPColor.primary)
                }
            }
        }
        .padding(EBPSpacing.md)
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat.lowercased() {
        case "material":      return .blue
        case "labor":         return .orange
        case "mobilization":  return .purple
        default:              return .secondary
        }
    }
}
