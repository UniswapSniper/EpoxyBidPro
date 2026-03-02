import SwiftUI

// ─── Step 3: Coating System ──────────────────────────────────────────────────

struct BidBuilderCoatingStep: View {

    @ObservedObject var vm: BidBuilderViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                stepHeader(
                    icon: "paintbrush.fill",
                    title: NSLocalizedString("coating.system", comment: ""),
                    subtitle: NSLocalizedString("coating.subtitle", comment: "")
                )

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: EBPSpacing.sm),
                    GridItem(.flexible(), spacing: EBPSpacing.sm),
                ], spacing: EBPSpacing.sm) {
                    ForEach(BidBuilderViewModel.CoatingSystemOption.allCases) { option in
                        coatingCard(option)
                    }
                }
                .ebpHPadding()

                if let selected = vm.selectedCoatingSystem {
                    selectedCoatingDetail(selected)
                }
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    // MARK: - Coating Card

    private func coatingCard(_ option: BidBuilderViewModel.CoatingSystemOption) -> some View {
        let isSelected = vm.selectedCoatingSystem == option
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(EBPAnimation.snappy) {
                vm.selectedCoatingSystem = option
                // Reset pricing when coating changes
                vm.pricingResult = nil
            }
        } label: {
            VStack(spacing: EBPSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: EBPRadius.sm)
                        .fill(option.tintColor.opacity(isSelected ? 0.20 : 0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: option.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(option.tintColor)
                }

                VStack(spacing: 2) {
                    Text(option.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Text(option.priceRange)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(option.tintColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, EBPSpacing.md)
            .padding(.horizontal, EBPSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .fill(EBPColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .strokeBorder(
                        isSelected ? option.tintColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .ebpShadowSubtle()
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(EBPAnimation.snappy, value: isSelected)
    }

    // MARK: - Selected Detail

    private func selectedCoatingDetail(_ option: BidBuilderViewModel.CoatingSystemOption) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.sm) {
                Image(systemName: option.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(option.tintColor)
                Text(option.displayName)
                    .font(.headline)
            }

            Text(option.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack {
                Label(NSLocalizedString("price.range", comment: ""), systemImage: "dollarsign.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(option.priceRange)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(option.tintColor)
            }
            .padding(.top, EBPSpacing.xs)
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
        .ebpHPadding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// ─── Step 4: Surface Prep ────────────────────────────────────────────────────

struct BidBuilderPrepStep: View {

    @ObservedObject var vm: BidBuilderViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                stepHeader(
                    icon: "wrench.and.screwdriver.fill",
                    title: NSLocalizedString("prep.details", comment: ""),
                    subtitle: NSLocalizedString("prep.subtitle", comment: "")
                )

                // ── Surface Condition ─────────────────────────────────────
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text(NSLocalizedString("surface.condition", comment: ""))
                        .font(.headline)
                        .ebpHPadding()

                    VStack(spacing: 0) {
                        ForEach(BidBuilderViewModel.SurfaceConditionOption.allCases) { option in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation {
                                    vm.surfaceCondition = option
                                    vm.pricingResult = nil
                                }
                            } label: {
                                conditionRow(option)
                            }
                            .buttonStyle(.plain)

                            if option != BidBuilderViewModel.SurfaceConditionOption.allCases.last {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                    .ebpShadowSubtle()
                    .ebpHPadding()
                }

                // ── Prep Complexity ───────────────────────────────────────
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text(NSLocalizedString("prep.complexity", comment: ""))
                        .font(.headline)
                        .ebpHPadding()

                    Picker("Prep", selection: $vm.prepComplexity) {
                        ForEach(BidBuilderViewModel.PrepComplexityOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .ebpHPadding()
                    .onChange(of: vm.prepComplexity) { _, _ in vm.pricingResult = nil }

                    prepDescription
                }

                // ── Access Difficulty ─────────────────────────────────────
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text(NSLocalizedString("access.difficulty", comment: ""))
                        .font(.headline)
                        .ebpHPadding()

                    Picker("Access", selection: $vm.accessDifficulty) {
                        ForEach(BidBuilderViewModel.AccessOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .ebpHPadding()
                    .onChange(of: vm.accessDifficulty) { _, _ in vm.pricingResult = nil }
                }

                // ── Complex Layout Toggle ─────────────────────────────────
                Toggle(isOn: $vm.isComplexLayout) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("complex.layout", comment: ""))
                            .font(.subheadline.weight(.medium))
                        Text(NSLocalizedString("complex.layout.hint", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(EBPColor.primary)
                .padding(EBPSpacing.md)
                .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                .ebpShadowSubtle()
                .ebpHPadding()
                .onChange(of: vm.isComplexLayout) { _, _ in vm.pricingResult = nil }

                // ── Crew & Hours ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text(NSLocalizedString("crew.hours", comment: ""))
                        .font(.headline)
                        .ebpHPadding()

                    HStack(spacing: EBPSpacing.lg) {
                        VStack(spacing: EBPSpacing.xs) {
                            Text(NSLocalizedString("crew.size", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Stepper("\(vm.crewCount)", value: $vm.crewCount, in: 1...10)
                                .onChange(of: vm.crewCount) { _, _ in vm.pricingResult = nil }
                        }

                        VStack(spacing: EBPSpacing.xs) {
                            Text(NSLocalizedString("est.hours", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                TextField("0", value: $vm.estimatedHours, format: .number)
                                    .keyboardType(.decimalPad)
                                    .font(.body.monospacedDigit())
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                                    .onChange(of: vm.estimatedHours) { _, _ in vm.pricingResult = nil }
                                Text(NSLocalizedString("hrs", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(EBPSpacing.md)
                    .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                    .ebpShadowSubtle()
                    .ebpHPadding()

                    Button {
                        vm.estimatedHours = vm.autoEstimateHours()
                    } label: {
                        Label(NSLocalizedString("auto.estimate", comment: ""), systemImage: "wand.and.stars")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(EBPColor.primary)
                    }
                    .ebpHPadding()
                }
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    // MARK: - Condition Row

    private func conditionRow(_ option: BidBuilderViewModel.SurfaceConditionOption) -> some View {
        let isSelected = vm.surfaceCondition == option
        return HStack(spacing: EBPSpacing.sm) {
            ZStack {
                Circle()
                    .fill(isSelected ? option.tint : option.tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: option.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : option.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(option.tint)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? option.tint.opacity(0.04) : Color.clear)
    }

    // MARK: - Prep Description

    private var prepDescription: some View {
        let text: String = switch vm.prepComplexity {
        case .light:    NSLocalizedString("prep.light.desc", comment: "")
        case .standard: NSLocalizedString("prep.standard.desc", comment: "")
        case .heavy:    NSLocalizedString("prep.heavy.desc", comment: "")
        }
        return Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .ebpHPadding()
    }
}
