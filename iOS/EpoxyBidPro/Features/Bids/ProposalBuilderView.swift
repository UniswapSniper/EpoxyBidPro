import SwiftUI
import SwiftData

// ─── ProposalBuilderView ──────────────────────────────────────────────────────
// Full-featured proposal editor: cover page branding, section content,
// template gallery, and live preview summary.
// Presented as a sheet from BidDetailView when the user taps "Build Proposal".

struct ProposalBuilderView: View {

    // MARK: - Inputs

    @Bindable var bid: Bid

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State — Navigation

    @State private var selectedSection: ProposalSection = .cover

    enum ProposalSection: String, CaseIterable, Identifiable {
        case cover      = "Cover"
        case summary    = "Summary"
        case scope      = "Scope"
        case products   = "Products"
        case terms      = "Terms"
        case branding   = "Branding"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .cover:    return "doc.richtext"
            case .summary:  return "text.quote"
            case .scope:    return "list.bullet.clipboard"
            case .products: return "shippingbox.fill"
            case .terms:    return "shield.lefthalf.filled"
            case .branding: return "paintpalette.fill"
            }
        }
    }

    // MARK: - State — Cover

    @State private var coverSubtitle  = "Professional Epoxy Flooring Proposal"
    @State private var preparedFor    = ""
    @State private var selectedTemplate: ProposalTemplate = .classic

    // MARK: - State — Summary / Scope (mirror bid fields, save on dismiss)

    @State private var executiveSummary: String = ""
    @State private var scopeNotes: String       = ""

    // MARK: - State — Products

    @State private var productLines: [ProductLine] = ProductLine.defaults

    struct ProductLine: Identifiable {
        var id = UUID()
        var name: String
        var detail: String
        var isIncluded: Bool
    }

    // MARK: - State — Terms

    @State private var warrantyText = "We provide a 1-year warranty on all coating systems against peeling, delamination, and defects in workmanship under normal use conditions."
    @State private var paymentTerms = "50% deposit required before work begins. Remaining balance due upon project completion."
    @State private var liabilityText = "Contractor is fully licensed and insured. Client is responsible for clearing the work area prior to scheduled start date."

    // MARK: - State — Branding

    @State private var brandPrimaryHex  = "#00FFF2"
    @State private var brandAccentHex   = "#0D0D0F"
    @State private var companyTagline   = "Precision Floors. Lasting Results."
    @State private var showLogoPlaceholder = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                sectionTabBar
                Divider()
                ZStack {
                    switch selectedSection {
                    case .cover:    coverSection
                    case .summary:  summarySection
                    case .scope:    scopeSection
                    case .products: productsSection
                    case .terms:    termsSection
                    case .branding: brandingSection
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Proposal Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .bold()
                }
            }
        }
        .onAppear { loadFromBid() }
    }

    // MARK: - Section Tab Bar

    private var sectionTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(ProposalSection.allCases) { section in
                    Button {
                        withAnimation(EBPAnimation.sectionSwitch) { selectedSection = section }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: section.icon)
                                .font(.caption.weight(.semibold))
                            Text(section.rawValue)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(selectedSection == section ? EBPColor.accent : .secondary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(
                            selectedSection == section
                                ? EBPColor.accent.opacity(0.12)
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, EBPSpacing.xs)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Cover Section

    private var coverSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {
                sectionHeader("Cover Page", icon: "doc.richtext")

                // Template Gallery
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Layout Template")
                        .font(.subheadline.weight(.semibold))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: EBPSpacing.md) {
                            ForEach(ProposalTemplate.allCases) { template in
                                templateCard(template)
                            }
                        }
                    }
                }

                // Cover fields
                formCard {
                    labeledField("Subtitle / Tagline", text: $coverSubtitle)
                    Divider()
                    labeledField("Prepared For", text: $preparedFor, placeholder: bid.client?.displayName ?? "Client name")
                }

                // Live preview card
                proposalPreviewCard
            }
            .padding(EBPSpacing.md)
        }
    }

    private func templateCard(_ template: ProposalTemplate) -> some View {
        VStack(spacing: EBPSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.md)
                    .fill(template.previewGradient)
                    .frame(width: 100, height: 130)
                    .overlay(
                        RoundedRectangle(cornerRadius: EBPRadius.md)
                            .stroke(selectedTemplate == template ? EBPColor.accent : Color.clear, lineWidth: 2)
                    )

                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.5)).frame(width: 60, height: 6)
                    RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.3)).frame(width: 48, height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.2)).frame(width: 52, height: 4)
                }
            }

            Text(template.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedTemplate == template ? EBPColor.accent : .primary)
        }
        .onTapGesture {
            withAnimation(EBPAnimation.snappy) { selectedTemplate = template }
        }
    }

    private var proposalPreviewCard: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text("Preview")
                .font(.subheadline.weight(.semibold))

            ZStack {
                selectedTemplate.previewGradient
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))

                VStack(alignment: .leading, spacing: 8) {
                    Text(companyTagline.isEmpty ? "Your Company" : companyTagline)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(bid.title.isEmpty ? "Flooring Proposal" : bid.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text(coverSubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    if !preparedFor.isEmpty {
                        Text("Prepared for \(preparedFor)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EBPSpacing.md)
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {
                sectionHeader("Executive Summary", icon: "text.quote")
                Text("Briefly explain the project scope, value delivered, and why your proposal stands out.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $executiveSummary)
                    .frame(minHeight: 200)
                    .padding(EBPSpacing.sm)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.sm))

                aiSuggestionCard(
                    title: "AI Suggestion",
                    body: "We specialize in epoxy and polyurea floor coatings that transform ordinary concrete into durable, high-gloss surfaces. This proposal outlines our recommended system for \(bid.client?.displayName ?? "your project"), covering \(Int(bid.totalSqFt)) sq ft with a \(bid.tier.capitalized)-tier coating package."
                )
            }
            .padding(EBPSpacing.md)
        }
    }

    // MARK: - Scope Section

    private var scopeSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {
                sectionHeader("Scope of Work", icon: "list.bullet.clipboard")
                Text("Detail the exact work that will be performed, including surface prep, coatings, and finishes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $scopeNotes)
                    .frame(minHeight: 200)
                    .padding(EBPSpacing.sm)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.sm))

                // Pricing summary inline
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Text("Pricing Summary")
                        .font(.subheadline.weight(.semibold))
                    scopePricingRow("Materials", (bid.materialCost as Decimal).formatted(.currency(code: "USD")))
                    scopePricingRow("Labor",     (bid.laborCost as Decimal).formatted(.currency(code: "USD")))
                    scopePricingRow("Markup",    (bid.markup as Decimal).formatted(.currency(code: "USD")))
                    Divider()
                    scopePricingRow("Total",     (bid.totalPrice as Decimal).formatted(.currency(code: "USD")), bold: true)
                }
                .padding(EBPSpacing.md)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            }
            .padding(EBPSpacing.md)
        }
    }

    private func scopePricingRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(bold ? .subheadline.weight(.bold) : .subheadline)
                .foregroundStyle(bold ? EBPColor.primary : .primary)
        }
    }

    // MARK: - Products Section

    private var productsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {
                sectionHeader("Product Information", icon: "shippingbox.fill")
                Text("Select which product details to include in the proposal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach($productLines) { $line in
                    HStack(alignment: .top, spacing: EBPSpacing.md) {
                        Toggle("", isOn: $line.isIncluded)
                            .labelsHidden()
                            .tint(EBPColor.primary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(line.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(line.isIncluded ? .primary : .secondary)
                            Text(line.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(EBPSpacing.md)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
            }
            .padding(EBPSpacing.md)
        }
    }

    // MARK: - Terms Section

    private var termsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {
                sectionHeader("Warranty & Terms", icon: "shield.lefthalf.filled")

                termsCard("Warranty", icon: "checkmark.seal.fill", color: .green, text: $warrantyText)
                termsCard("Payment Terms", icon: "creditcard.fill", color: EBPColor.primary, text: $paymentTerms)
                termsCard("Liability", icon: "building.2.fill", color: .orange, text: $liabilityText)
            }
            .padding(EBPSpacing.md)
        }
    }

    private func termsCard(_ title: String, icon: String, color: Color, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.sm) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.subheadline.weight(.semibold))
            }
            TextEditor(text: text)
                .frame(minHeight: 90)
                .padding(EBPSpacing.xs)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: EBPRadius.xs))
        }
        .padding(EBPSpacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Branding Section

    private var brandingSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {
                sectionHeader("Branding & Identity", icon: "paintpalette.fill")

                // Logo placeholder
                VStack(spacing: EBPSpacing.sm) {
                    Text("Company Logo").font(.subheadline.weight(.semibold))

                    ZStack {
                        RoundedRectangle(cornerRadius: EBPRadius.md)
                            .fill(Color(.secondarySystemBackground))
                            .frame(height: 110)
                        if showLogoPlaceholder {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.largeTitle)
                                    .foregroundStyle(EBPColor.primary.opacity(0.5))
                                Text("Tap to upload logo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onTapGesture {
                        // Logo upload triggers native photo picker — wired in future phase
                    }
                }

                formCard {
                    labeledField("Company Tagline", text: $companyTagline, placeholder: "Your slogan here")
                    Divider()
                    labeledField("Primary Color (hex)", text: $brandPrimaryHex, placeholder: "#00FFF2")
                    Divider()
                    labeledField("Accent Color (hex)", text: $brandAccentHex, placeholder: "#0D0D0F")
                }

                // Color preview swatches
                HStack(spacing: EBPSpacing.md) {
                    swatchPreview("Primary", hex: brandPrimaryHex)
                    swatchPreview("Accent", hex: brandAccentHex)
                }
            }
            .padding(EBPSpacing.md)
        }
    }

    private func swatchPreview(_ label: String, hex: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: EBPRadius.sm)
                .fill(Color(hex: hex) ?? EBPColor.primary)
                .frame(height: 48)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Reusable Sub-views

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(EBPColor.primary)
            Text(title)
                .font(.title3.weight(.bold))
        }
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            TextField(placeholder.isEmpty ? label : placeholder, text: text)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(EBPSpacing.md)
    }

    private func aiSuggestionCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EBPColor.accent)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.accent)
                Spacer()
                Button("Use") {
                    executiveSummary = body
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(EBPColor.accent)
            }

            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: EBPRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.sm)
                .stroke(EBPColor.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Load / Save

    private func loadFromBid() {
        executiveSummary = bid.executiveSummary
        scopeNotes       = bid.scopeNotes
        preparedFor      = bid.client?.displayName ?? ""
    }

    private func saveAndDismiss() {
        bid.executiveSummary = executiveSummary
        bid.scopeNotes       = scopeNotes
        try? modelContext.save()

        // Save a version snapshot
        let version = BidVersion(
            bidId: bid.id,
            versionNumber: (bid.notes.filter { $0 == "V" }.count) + 1,
            snapshotJson: buildSnapshotJson(),
            changeNote: "Proposal updated via builder"
        )
        modelContext.insert(version)
        try? modelContext.save()

        dismiss()
    }

    private func buildSnapshotJson() -> String {
        let dict: [String: String] = [
            "bidNumber": bid.bidNumber,
            "title": bid.title,
            "totalPrice": "\(bid.totalPrice)",
            "tier": bid.tier,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}

// ─── ProposalTemplate ─────────────────────────────────────────────────────────

enum ProposalTemplate: String, CaseIterable, Identifiable {
    case classic    = "Classic"
    case modern     = "Modern"
    case bold       = "Bold"
    case minimal    = "Minimal"

    var id: String { rawValue }

    var previewGradient: LinearGradient {
        switch self {
        case .classic:
            return LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.06), Color(red: 0.12, green: 0.12, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .modern:
            return LinearGradient(colors: [Color(red: 0.00, green: 0.80, blue: 0.75), Color(red: 0.00, green: 0.40, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bold:
            return LinearGradient(colors: [Color(red: 0.55, green: 0.00, blue: 0.85), Color(red: 0.12, green: 0.00, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .minimal:
            return LinearGradient(colors: [Color(.secondarySystemBackground), Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// ─── ProductLine defaults ─────────────────────────────────────────────────────

private extension ProposalBuilderView.ProductLine {
    static var defaults: [ProposalBuilderView.ProductLine] {
        [
            .init(name: "Surface Preparation", detail: "Diamond grinding, crack repair, and moisture mitigation", isIncluded: true),
            .init(name: "Primer Coat", detail: "100% solids epoxy primer for maximum adhesion", isIncluded: true),
            .init(name: "Base Coat System", detail: "Selected coating per project specification", isIncluded: true),
            .init(name: "Decorative Flake Broadcast", detail: "Full broadcast vinyl chip blend for aesthetic and texture", isIncluded: true),
            .init(name: "Polyaspartic Topcoat", detail: "UV-stable, chemical-resistant clear finish coat", isIncluded: true),
            .init(name: "Anti-Slip Additive", detail: "Fine aggregate added to topcoat for traction", isIncluded: false),
            .init(name: "Moisture Vapor Barrier", detail: "High-build moisture mitigation primer for problem slabs", isIncluded: false),
        ]
    }
}

// ─── Color hex initializer ────────────────────────────────────────────────────

private extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double(val & 0xFF)         / 255
        )
    }
}
