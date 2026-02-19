import SwiftUI
import SwiftData

// ─── BidDetailView ─────────────────────────────────────────────────────────────
// Full detail view for a single bid, with tabs for overview, line items,
// AI suggestions, and proposal delivery controls.

struct BidDetailView: View {

    // MARK: - Inputs

    let bid: Bid

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - View Model

    @StateObject private var vm = BidViewModel()

    // MARK: - Local State

    @State private var selectedTab: BidTab = .overview
    @State private var isPresentingSignature = false
    @State private var isPresentingSend = false
    @State private var isShowingConvertAlert = false
    @State private var isShowingDeclineAlert = false
    @State private var declineReason = ""
    @State private var sendDeliveryMethod = "email"
    @State private var sendCustomMessage = ""

    enum BidTab: String, CaseIterable {
        case overview   = "Overview"
        case lineItems  = "Line Items"
        case aiInsights = "AI Insights"
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: EBPSpacing.lg) {
                headerCard
                tabPicker
                tabContent
                actionButtons
            }
            .padding(EBPSpacing.md)
        }
        .navigationTitle(bid.bidNumber.isEmpty ? "Draft" : bid.bidNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $isPresentingSignature) {
            SignatureView(bid: bid, onSigned: handleSignature, onCancel: { isPresentingSignature = false })
        }
        .sheet(isPresented: $isPresentingSend) {
            sendSheet
        }
        .alert("Convert to Job?", isPresented: $isShowingConvertAlert) {
            Button("Convert", role: .destructive) {
                Task { await vm.convertToJob(bid, context: modelContext) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will create a new job from this bid. The bid will remain in SIGNED status.")
        }
        .alert("Decline Bid", isPresented: $isShowingDeclineAlert) {
            TextField("Reason (optional)", text: $declineReason)
            Button("Decline", role: .destructive) {
                Task { await vm.declineBid(bid, reason: declineReason.isEmpty ? nil : declineReason, context: modelContext) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay {
            if vm.isLoading || vm.isSending || vm.isGeneratingPdf {
                loadingOverlay
            }
        }
        .errorAlert(message: $vm.errorMessage)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: EBPSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bid.title.isEmpty ? "Untitled Bid" : bid.title)
                        .font(.title3.weight(.bold))
                    if let client = bid.client {
                        Label(client.displayName, systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                BidStatusBadge(status: bid.status)
            }

            Divider()

            // Pricing summary grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: EBPSpacing.sm) {
                metricCell(label: "Total", value: (bid.totalPrice as Decimal).formatted(.currency(code: "USD")), highlight: true)
                metricCell(label: "Sq Ft", value: "\(Int(bid.totalSqFt).formatted())")
                metricCell(label: "Margin", value: "\(Int((NSDecimalNumber(decimal: bid.profitMargin).doubleValue * 100).rounded()))%")
                metricCell(label: "Materials", value: bid.materialCost.formatted(.currency(code: "USD")))
                metricCell(label: "Labor", value: bid.laborCost.formatted(.currency(code: "USD")))
                metricCell(label: "Duration", value: estimatedDaysText)
            }

            if let validUntil = bid.validUntil {
                expiryBanner(date: validUntil)
            }
        }
        .padding(EBPSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var estimatedDaysText: String {
        if let measurement = bid.measurement {
            _ = measurement  // suppress warning; days come from bid
        }
        return "–"  // estimatedDays is on Bid — would extend model to add
    }

    @ViewBuilder
    private func expiryBanner(date: Date) -> some View {
        let isExpiringSoon = date.timeIntervalSinceNow < 86_400 * 3
        let isPast = date < Date()
        HStack(spacing: 6) {
            Image(systemName: isPast ? "exclamationmark.triangle.fill" : "clock")
                .foregroundStyle(isPast ? .red : (isExpiringSoon ? .orange : .secondary))
            Text(isPast ? "Expired \(date.relativeFormatted)" : "Expires \(date.relativeFormatted)")
                .font(.caption.weight(.medium))
                .foregroundStyle(isPast ? .red : (isExpiringSoon ? .orange : .secondary))
        }
    }

    private func metricCell(label: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(highlight ? .title3.weight(.bold) : .subheadline.weight(.semibold))
                .foregroundStyle(highlight ? EBPColor.primary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, EBPSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(highlight ? EBPColor.primary.opacity(0.08) : Color.clear)
        )
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(BidTab.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewTab
        case .lineItems:
            lineItemsTab
        case .aiInsights:
            aiInsightsTab
        }
    }

    // ── Overview Tab ──────────────────────────────────────────────────────────

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {

            if !bid.executiveSummary.isEmpty {
                sectionCard(title: "Executive Summary") {
                    Text(bid.executiveSummary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if !bid.scopeNotes.isEmpty {
                sectionCard(title: "Scope of Work") {
                    Text(bid.scopeNotes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if let areas = bid.measurement?.areas, !areas.isEmpty {
                sectionCard(title: "Area Breakdown") {
                    ForEach(areas) { area in
                        HStack {
                            Label(area.name, systemImage: "square.on.square")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(area.squareFeet).formatted()) sq ft")
                                .font(.subheadline.weight(.medium))
                        }
                        Divider()
                    }
                    HStack {
                        Text("Total").font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(Int(bid.totalSqFt).formatted()) sq ft").font(.subheadline.weight(.bold))
                    }
                }
            }

            sectionCard(title: "Coating Details") {
                detailRow("Coating System", bid.coatingSystem.formatted)
                detailRow("Tier", bid.tier.capitalized)
                detailRow("Surface Condition", bid.coatingSystem.formatted)
            }

            pricingBreakdownCard
        }
    }

    private var pricingBreakdownCard: some View {
        sectionCard(title: "Pricing Breakdown") {
            detailRow("Materials", (bid.materialCost as Decimal).formatted(.currency(code: "USD")))
            detailRow("Labor", (bid.laborCost as Decimal).formatted(.currency(code: "USD")))
            detailRow("Markup", (bid.markup as Decimal).formatted(.currency(code: "USD")))
            detailRow("Tax", (bid.taxAmount as Decimal).formatted(.currency(code: "USD")))
            Divider()
            HStack {
                Text("Total").font(.subheadline.weight(.bold))
                Spacer()
                Text((bid.totalPrice as Decimal).formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EBPColor.primary)
            }
        }
    }

    // ── Line Items Tab ────────────────────────────────────────────────────────

    private var lineItemsTab: some View {
        VStack(spacing: 0) {
            if bid.lineItems.isEmpty {
                ContentUnavailableView(
                    "No Line Items",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Line items will appear here once the bid is built.")
                )
            } else {
                ForEach(bid.lineItems.sorted(by: { $0.sortOrder < $1.sortOrder })) { item in
                    lineItemRow(item)
                    Divider().padding(.leading, EBPSpacing.md)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func lineItemRow(_ item: BidLineItem) -> some View {
        HStack(alignment: .top, spacing: EBPSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description.isEmpty ? "Item" : item.description)
                    .font(.subheadline.weight(.medium))
            Text("\(item.quantity.formatted()) × \(item.unitPrice.formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.amount as Decimal, format: .currency(code: "USD"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(EBPColor.primary)
        }
        .padding(EBPSpacing.md)
    }

    // ── AI Insights Tab ───────────────────────────────────────────────────────

    private var aiInsightsTab: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {

            if bid.aiRiskFlags.isEmpty && bid.aiUpsells.isEmpty {
                ContentUnavailableView(
                    "No AI Insights Yet",
                    systemImage: "brain",
                    description: Text("Use the AI Suggest feature from the bid builder to generate insights.")
                )
            } else {
                if !bid.aiRiskFlags.isEmpty {
                    sectionCard(title: "⚠️ Risk Flags") {
                        ForEach(bid.aiRiskFlags, id: \.self) { flag in
                            Label(flag, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                                .padding(.vertical, 2)
                        }
                    }
                }

                if !bid.aiUpsells.isEmpty {
                    sectionCard(title: "💡 Upsell Opportunities") {
                        ForEach(bid.aiUpsells, id: \.self) { upsell in
                            Label(upsell, systemImage: "lightbulb")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                                .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: EBPSpacing.sm) {
            switch bid.status {
            case "DRAFT":
                primaryButton("Generate & Send Proposal", icon: "paperplane.fill") {
                    isPresentingSend = true
                }

            case "SENT", "VIEWED":
                HStack(spacing: EBPSpacing.sm) {
                    secondaryButton("Resend", icon: "arrow.clockwise") {
                        isPresentingSend = true
                    }
                    primaryButton("Collect Signature", icon: "signature") {
                        isPresentingSignature = true
                    }
                }
                Button("Mark as Declined", role: .destructive) {
                    isShowingDeclineAlert = true
                }
                .font(.subheadline)
                .foregroundStyle(.red)

            case "SIGNED":
                primaryButton("Convert to Job", icon: "briefcase.fill") {
                    isShowingConvertAlert = true
                }
                secondaryButton("View Signed Proposal", icon: "doc.fill") {
                    Task { await vm.generatePdf(for: bid) }
                }

            default:
                EmptyView()
            }

            if !bid.pdfUrl.isEmpty, let url = URL(string: bid.pdfUrl) {
                Link(destination: url) {
                    Label("View Proposal PDF", systemImage: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(EBPColor.primary)
                }
            }
        }
    }

    // MARK: - Send Sheet

    private var sendSheet: some View {
        NavigationStack {
            Form {
                Section("Delivery Method") {
                    Picker("Method", selection: $sendDeliveryMethod) {
                        Text("Email").tag("email")
                        Text("SMS").tag("sms")
                        Text("Both").tag("both")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Custom Message (optional)") {
                    TextEditor(text: $sendCustomMessage)
                        .frame(minHeight: 80)
                }

                Section {
                    Button {
                        isPresentingSend = false
                        Task {
                            await vm.sendBid(
                                bid,
                                deliveryMethod: sendDeliveryMethod,
                                customMessage: sendCustomMessage.isEmpty ? nil : sendCustomMessage
                            )
                        }
                    } label: {
                        Label("Send Proposal", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(EBPColor.primary)
                }
            }
            .navigationTitle("Send Proposal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresentingSend = false }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    Task { await vm.generatePdf(for: bid) }
                } label: {
                    Label("Preview PDF", systemImage: "doc.richtext")
                }

                Button {
                    Task { await vm.cloneBid(bid, context: modelContext) }
                } label: {
                    Label("Clone Bid", systemImage: "doc.on.doc")
                }

                if bid.status != "SIGNED" {
                    Divider()
                    Button(role: .destructive) {
                        vm.deleteBid(bid, context: modelContext)
                        dismiss()
                    } label: {
                        Label("Delete Bid", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Signature Handler

    private func handleSignature(dataUrl: String, signerName: String, signerEmail: String?) {
        isPresentingSignature = false
        Task {
            await vm.submitSignature(
                bid: bid,
                signerName: signerName,
                signerEmail: signerEmail,
                dataUrl: dataUrl,
                context: modelContext
            )
        }
    }

    // MARK: - Reusable sub-views

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(EBPColor.primary)
            content()
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 2)
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(EBPColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding()
                .background(EBPColor.primary.opacity(0.1))
                .foregroundStyle(EBPColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView(vm.isSending ? "Sending proposal…" : vm.isGeneratingPdf ? "Generating PDF…" : "Loading…")
                .padding(EBPSpacing.lg)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// ─── String helpers ───────────────────────────────────────────────────────────

private extension String {
    var formatted: String {
        self.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

private extension Date {
    var relativeFormatted: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: self, relativeTo: Date())
    }
}

// ─── Error Alert Modifier ─────────────────────────────────────────────────────

private struct ErrorAlertModifier: ViewModifier {
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.alert("Error", isPresented: .init(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

private extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(message: message))
    }
}
