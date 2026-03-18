import SwiftUI

// ─── BusinessSetupView ───────────────────────────────────────────────────────
// Multi-step business profile setup shown after Sign in with Apple.
// Collects company info, logo, and pricing defaults before unlocking app.

struct BusinessSetupView: View {

    @Environment(AuthManager.self) private var authManager
    @State private var step: SetupStep = .company
    @State private var showImagePicker = false

    enum SetupStep: Int, CaseIterable {
        case company = 0
        case pricing = 1
        case review  = 2

        var title: String {
            switch self {
            case .company: return "Company Info"
            case .pricing: return "Pricing Defaults"
            case .review:  return "Review & Finish"
            }
        }

        var icon: String {
            switch self {
            case .company: return "building.2.fill"
            case .pricing: return "dollarsign.circle.fill"
            case .review:  return "checkmark.seal.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Progress ──────────────────────────────────────────────
                progressHeader

                // ── Content ───────────────────────────────────────────────
                TabView(selection: $step) {
                    companyStep.tag(SetupStep.company)
                    pricingStep.tag(SetupStep.pricing)
                    reviewStep.tag(SetupStep.review)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(EBPAnimation.snappy, value: step)

                // ── Bottom Bar ────────────────────────────────────────────
                bottomBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Business Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.xs) {
                ForEach(SetupStep.allCases, id: \.rawValue) { s in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(s.rawValue <= step.rawValue ? EBPColor.primary : Color(.systemGray4))
                                .frame(width: 32, height: 32)
                            Image(systemName: s.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(s.rawValue <= step.rawValue ? .white : .secondary)
                        }
                        Text(s.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(s.rawValue <= step.rawValue ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, EBPSpacing.md)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    Capsule()
                        .fill(EBPColor.primaryGradient)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, EBPSpacing.md)
        }
        .padding(.vertical, EBPSpacing.md)
        .background(Color(.systemBackground))
    }

    private var progress: CGFloat {
        CGFloat(step.rawValue + 1) / CGFloat(SetupStep.allCases.count)
    }

    // MARK: - Step 1: Company

    private var companyStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                // Logo upload placeholder
                VStack(spacing: EBPSpacing.sm) {
                    Button {
                        showImagePicker = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: EBPRadius.lg)
                                .fill(EBPColor.primary.opacity(0.06))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: EBPRadius.lg)
                                        .strokeBorder(EBPColor.primary.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                )
                            VStack(spacing: EBPSpacing.xs) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(EBPColor.primary)
                                Text("Add Logo")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(EBPColor.primary)
                            }
                        }
                    }
                    Text("Your logo appears on proposals & invoices")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Company fields
                VStack(spacing: EBPSpacing.md) {
                    floatingField("Company Name", text: $authManager.businessName, icon: "building.2")
                    floatingField("Business Phone", text: $authManager.businessPhone, icon: "phone.fill", keyboard: .phonePad)
                    floatingField("Business Email", text: $authManager.businessEmail, icon: "envelope.fill", keyboard: .emailAddress)
                    floatingField("License / Registration #", text: $authManager.businessLicenseNumber, icon: "doc.text.fill")
                }

                Divider()

                // Address
                VStack(spacing: EBPSpacing.md) {
                    Text("Business Address")
                        .font(.headline)

                    floatingField("Street Address", text: $authManager.businessAddress, icon: "mappin")
                    HStack(spacing: EBPSpacing.sm) {
                        floatingField("City", text: $authManager.businessCity, icon: "")
                        floatingField("State", text: $authManager.businessState, icon: "")
                            .frame(width: 80)
                        floatingField("ZIP", text: $authManager.businessZip, icon: "", keyboard: .numberPad)
                            .frame(width: 90)
                    }
                }
            }
            .padding(EBPSpacing.md)
        }
    }

    // MARK: - Step 2: Pricing

    private var pricingStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                    Text("Set Your Defaults")
                        .font(.title3.bold())
                    Text("These are used as starting points when creating bids. You can override them per bid.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: EBPSpacing.md) {
                    pricingRow(
                        label: "Labor Rate",
                        value: $authManager.defaultLaborRate,
                        unit: "$/hr",
                        icon: "person.fill",
                        tint: .orange,
                        range: 20...150
                    )

                    pricingRow(
                        label: "Overhead",
                        value: $authManager.defaultOverheadRate,
                        unit: "%",
                        icon: "building.fill",
                        tint: .purple,
                        range: 5...40
                    )

                    pricingRow(
                        label: "Default Markup",
                        value: $authManager.defaultMarkup,
                        unit: "%",
                        icon: "arrow.up.right",
                        tint: EBPColor.success,
                        range: 10...60
                    )

                    pricingRow(
                        label: "Tax Rate",
                        value: $authManager.defaultTaxRate,
                        unit: "%",
                        icon: "doc.text",
                        tint: .secondary,
                        range: 0...15
                    )

                    pricingRow(
                        label: "Mobilization Fee",
                        value: $authManager.defaultMobilizationFee,
                        unit: "$",
                        icon: "truck.box.fill",
                        tint: .teal,
                        range: 0...500
                    )

                    pricingRow(
                        label: "Minimum Job Price",
                        value: $authManager.defaultMinimumJobPrice,
                        unit: "$",
                        icon: "banknote",
                        tint: EBPColor.primary,
                        range: 0...3000
                    )
                }

                // Quick guide
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    HStack(spacing: EBPSpacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(EBPColor.warning)
                        Text("Tip")
                            .font(.subheadline.weight(.bold))
                    }
                    Text("Most epoxy contractors use 20–30% markup on materials + labor. Start at 25% and adjust based on your market.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(EBPSpacing.md)
                .background(EBPColor.warning.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.md))
            }
            .padding(EBPSpacing.md)
        }
    }

    // MARK: - Step 3: Review

    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: EBPSpacing.lg) {

                // Success hero
                VStack(spacing: EBPSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(EBPColor.success.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(EBPColor.success)
                    }
                    Text("You're All Set!")
                        .font(.title2.bold())
                    Text("Here's a summary of your business profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, EBPSpacing.md)

                // Company summary
                reviewSection(title: "Company", icon: "building.2.fill") {
                    reviewRow("Name", authManager.businessName.isEmpty ? "—" : authManager.businessName)
                    reviewRow("Phone", authManager.businessPhone.isEmpty ? "—" : authManager.businessPhone)
                    reviewRow("Email", authManager.businessEmail.isEmpty ? "—" : authManager.businessEmail)
                    if !authManager.businessAddress.isEmpty {
                        reviewRow("Address", "\(authManager.businessAddress), \(authManager.businessCity) \(authManager.businessState) \(authManager.businessZip)")
                    }
                    if !authManager.businessLicenseNumber.isEmpty {
                        reviewRow("License", authManager.businessLicenseNumber)
                    }
                }

                // Pricing summary
                reviewSection(title: "Pricing Defaults", icon: "dollarsign.circle.fill") {
                    reviewRow("Labor Rate", "$\(Int(authManager.defaultLaborRate))/hr")
                    reviewRow("Overhead", "\(Int(authManager.defaultOverheadRate))%")
                    reviewRow("Markup", "\(Int(authManager.defaultMarkup))%")
                    reviewRow("Tax Rate", "\(Int(authManager.defaultTaxRate))%")
                    reviewRow("Mobilization", "$\(Int(authManager.defaultMobilizationFee))")
                    reviewRow("Min Job Price", "$\(Int(authManager.defaultMinimumJobPrice))")
                }

                Text("You can change these anytime in Settings → Company Profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(EBPSpacing.md)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if step != .company {
                Button("Back") {
                    withAnimation { step = SetupStep(rawValue: step.rawValue - 1) ?? .company }
                }
                .foregroundStyle(EBPColor.primary)
            }

            Spacer()

            if step == .review {
                EBPButton(title: "Launch EpoxyBidPro", icon: "rocket.fill", style: .primary, isFullWidth: false) {
                    authManager.completeBusinessSetup()
                }
            } else {
                Button {
                    withAnimation { step = SetupStep(rawValue: step.rawValue + 1) ?? .review }
                } label: {
                    HStack(spacing: EBPSpacing.xs) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, EBPSpacing.lg)
                    .padding(.vertical, 12)
                    .background(EBPColor.primaryGradient, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                }
            }
        }
        .padding(EBPSpacing.md)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func floatingField(
        _ label: String,
        text: Binding<String>,
        icon: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(EBPColor.primary)
                    .frame(width: 20)
            }
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
        }
        .padding(EBPSpacing.sm + 2)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
    }

    private func pricingRow(
        label: String,
        value: Binding<Double>,
        unit: String,
        icon: String,
        tint: Color,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(unit == "%" || unit == "$/hr" ? "" : unit)\(Int(value.wrappedValue))\(unit == "%" || unit == "$/hr" ? unit : "")")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
            }
            Slider(value: value, in: range, step: 1)
                .tint(tint)
        }
        .padding(EBPSpacing.md)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    private func reviewSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(EBPColor.primary)
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}
