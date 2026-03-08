import SwiftUI
import SwiftData

// ─── BidBuilderView ───────────────────────────────────────────────────────────
// Multi-step wizard for creating a new bid.
// Flow: Client → Measurement → Coating → Prep → Pricing → AI → Line Items → Review

struct BidBuilderView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = BidBuilderViewModel()
    @State private var currentStep: BidBuilderStep = .client
    @State private var direction: Edge = .trailing
    @State private var showCancelConfirm = false
    
    var initialMeasurement: Measurement? = nil
    var initialCoating: BidBuilderViewModel.CoatingSystemOption? = nil

    enum BidBuilderStep: Int, CaseIterable {
        case client = 0
        case measurement
        case coating
        case prep
        case pricing
        case aiInsights
        case lineItems
        case review

        var title: String {
            switch self {
            case .client:     return "Client"
            case .measurement: return "Measurement"
            case .coating:    return "Coating"
            case .prep:       return "Prep"
            case .pricing:    return "Pricing"
            case .aiInsights: return "AI Insights"
            case .lineItems:  return "Line Items"
            case .review:     return "Review"
            }
        }

        var icon: String {
            switch self {
            case .client:     return "person.fill"
            case .measurement: return "ruler.fill"
            case .coating:    return "paintbrush.fill"
            case .prep:       return "wrench.and.screwdriver.fill"
            case .pricing:    return "dollarsign.circle.fill"
            case .aiInsights: return "brain"
            case .lineItems:  return "list.bullet.rectangle"
            case .review:     return "checkmark.seal.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Progress Bar ────────────────────────────────────────────
                stepProgressBar

                // ── Step Content ────────────────────────────────────────────
                ZStack {
                    stepContent
                        .id(currentStep)
                        .transition(.asymmetric(
                            insertion: .move(edge: direction).combined(with: .opacity),
                            removal: .move(edge: direction == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
                .animation(EBPAnimation.snappy, value: currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Bottom Navigation ───────────────────────────────────────
                bottomBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Bid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if vm.hasUnsavedChanges {
                            showCancelConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Discard Bid?", isPresented: $showCancelConfirm) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You'll lose any unsaved changes to this bid.")
            }
            .overlay {
                if vm.isGeneratingPricing {
                    pricingLoadingOverlay
                }
            }
        }
        .interactiveDismissDisabled(vm.hasUnsavedChanges)
        .onAppear {
            if let m = initialMeasurement {
                vm.selectedMeasurement = m
                if let c = initialCoating {
                    // Coating pre-selected from scan — jump to prep step
                    vm.selectedCoatingSystem = c
                    currentStep = .prep
                } else {
                    // Measurement only — jump to coating selection
                    currentStep = .coating
                }
            }
        }
    }

    // MARK: - Step Content Router

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .client:
            BidBuilderClientStep(vm: vm)
        case .measurement:
            BidBuilderMeasurementStep(vm: vm)
        case .coating:
            BidBuilderCoatingStep(vm: vm)
        case .prep:
            BidBuilderPrepStep(vm: vm)
        case .pricing:
            BidBuilderPricingStep(vm: vm)
        case .aiInsights:
            BidBuilderAIStep(vm: vm)
        case .lineItems:
            BidBuilderLineItemsStep(vm: vm)
        case .review:
            BidBuilderReviewStep(vm: vm)
        }
    }

    // MARK: - Progress Bar

    private var stepProgressBar: some View {
        VStack(spacing: EBPSpacing.sm) {
            // Step dots
            HStack(spacing: EBPSpacing.xs) {
                ForEach(BidBuilderStep.allCases, id: \.rawValue) { step in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(stepFill(for: step))
                                .frame(width: 28, height: 28)

                            if step.rawValue < currentStep.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: step.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(step == currentStep ? .white : .secondary)
                            }
                        }

                        Text(step.title)
                            .font(.system(size: 8, weight: step == currentStep ? .bold : .medium))
                            .foregroundStyle(step == currentStep ? EBPColor.primary : .secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, EBPSpacing.sm)

            // Continuous progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 3)

                    Capsule()
                        .fill(EBPColor.primaryGradient)
                        .frame(width: geo.size.width * progressFraction, height: 3)
                        .animation(EBPAnimation.snappy, value: currentStep)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, EBPSpacing.md)
        }
        .padding(.top, EBPSpacing.sm)
        .padding(.bottom, EBPSpacing.xs)
        .background(.bar)
    }

    private func stepFill(for step: BidBuilderStep) -> some ShapeStyle {
        if step.rawValue < currentStep.rawValue {
            return AnyShapeStyle(EBPColor.success)
        } else if step == currentStep {
            return AnyShapeStyle(EBPColor.primary)
        } else {
            return AnyShapeStyle(Color(.systemGray5))
        }
    }

    private var progressFraction: CGFloat {
        let total = CGFloat(BidBuilderStep.allCases.count - 1)
        return total > 0 ? CGFloat(currentStep.rawValue) / total : 0
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: EBPSpacing.md) {
            if currentStep != .client {
                Button {
                    direction = .leading
                    withAnimation { goBack() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))
                        Text("Back")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(EBPColor.primary)
                    .padding(.vertical, 14)
                    .padding(.horizontal, EBPSpacing.lg)
                    .background(EBPColor.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                }
            }

            Spacer()

            if currentStep == .review {
                Button {
                    saveBid()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                        Text("Save Bid")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, EBPSpacing.xl)
                    .background(EBPColor.successGradient)
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                    .ebpShadowMedium()
                }
            } else {
                Button {
                    direction = .trailing
                    withAnimation { goForward() }
                } label: {
                    HStack(spacing: 4) {
                        Text(nextButtonLabel)
                            .font(.headline)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, EBPSpacing.xl)
                    .background(canProceed ? EBPColor.primaryGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                    .ebpShadowMedium()
                }
                .disabled(!canProceed)
            }
        }
        .padding(EBPSpacing.md)
        .background(.bar)
    }

    private var nextButtonLabel: String {
        switch currentStep {
        case .prep:    return "Calculate Price"
        case .pricing: return "AI Insights"
        default:       return "Next"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case .client:      return true // client is optional
        case .measurement: return vm.totalSqFt > 0
        case .coating:     return vm.selectedCoatingSystem != nil
        case .prep:        return true
        case .pricing:     return vm.pricingResult != nil
        case .aiInsights:  return true
        case .lineItems:   return true
        case .review:      return true
        }
    }

    // MARK: - Navigation

    private func goForward() {
        let allSteps = BidBuilderStep.allCases
        if let idx = allSteps.firstIndex(of: currentStep), idx < allSteps.count - 1 {
            let nextStep = allSteps[idx + 1]
            // Trigger pricing when moving to pricing step
            if nextStep == .pricing && vm.pricingResult == nil {
                Task { await vm.calculatePricing() }
            }
            currentStep = nextStep
        }
    }

    private func goBack() {
        let allSteps = BidBuilderStep.allCases
        if let idx = allSteps.firstIndex(of: currentStep), idx > 0 {
            currentStep = allSteps[idx - 1]
        }
    }

    private func saveBid() {
        let bid = vm.buildAndSaveBid(context: modelContext)
        if bid != nil {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }

    // MARK: - Loading Overlay

    private var pricingLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: EBPSpacing.md) {
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.white)
                Text("Calculating pricing…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(EBPSpacing.xl)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: EBPRadius.lg))
        }
    }
}
