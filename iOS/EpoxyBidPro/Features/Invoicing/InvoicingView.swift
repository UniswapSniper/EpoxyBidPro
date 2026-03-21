import SwiftUI
import SwiftData

// ─── InvoicingView ────────────────────────────────────────────────────────────
// Full invoicing screen with auto-generation from jobs, Stripe payment links,
// overdue tracking, and deposit management.

struct InvoicingView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @Query(sort: \Lead.createdAt, order: .reverse) private var workflowLeads: [Lead]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var allInvoices: [Invoice]
    @Query(sort: \Bid.createdAt, order: .reverse) private var allBids: [Bid]
    @Query(sort: \Job.createdAt, order: .reverse) private var workflowJobs: [Job]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var workflowMeasurements: [Measurement]

    @State private var selectedFilter: InvoiceFilter = .all
    @State private var showCreateInvoice = false
    @State private var selectedInvoice: Invoice? = nil
    @State private var searchText = ""

    enum InvoiceFilter: String, CaseIterable {
        case all      = "All"
        case draft    = "DRAFT"
        case sent     = "SENT"
        case overdue  = "OVERDUE"
        case paid     = "PAID"
        case partial  = "PARTIAL"

        var label: String {
            switch self {
            case .all:     return "All"
            case .draft:   return "Draft"
            case .sent:    return "Sent"
            case .overdue: return "Overdue"
            case .paid:    return "Paid"
            case .partial: return "Partial"
            }
        }

        var color: Color {
            switch self {
            case .all:     return EBPColor.primary
            case .draft:   return .secondary
            case .sent:    return EBPColor.primary
            case .overdue: return EBPColor.error
            case .paid:    return EBPColor.success
            case .partial: return EBPColor.secondary
            }
        }
    }

    private var filteredInvoices: [Invoice] {
        var results = Array(allInvoices)

        // Apply filter
        switch selectedFilter {
        case .all: break
        case .overdue:
            results = results.filter { $0.isOverdue }
        default:
            results = results.filter { $0.status == selectedFilter.rawValue }
        }

        // Apply search
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            results = results.filter {
                $0.invoiceNumber.lowercased().contains(lower) ||
                ($0.client?.displayName.lowercased().contains(lower) ?? false)
            }
        }

        return results
    }

    private var signedBidsReadyForInvoicing: [Bid] {
        let alreadyInvoicedNumbers = Set(allInvoices.compactMap { invoice in
            invoice.notes
                .split(separator: "\n")
                .first(where: { $0.hasPrefix("SOURCE_BID:") })
                .map { String($0.replacingOccurrences(of: "SOURCE_BID:", with: "")) }
        })

        return allBids.filter {
            $0.status == "SIGNED" && !alreadyInvoicedNumbers.contains($0.bidNumber)
        }
    }

    private var workflowSnapshot: WorkflowKPISnapshot {
        WorkflowKPIService.snapshot(
            leads: workflowLeads,
            bids: allBids,
            jobs: workflowJobs,
            invoices: allInvoices,
            measurements: workflowMeasurements
        )
    }

    private var nextAction: WorkflowNextAction {
        WorkflowKPIService.nextBestAction(from: workflowSnapshot)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                WorkflowKPIBanner(snapshot: workflowSnapshot)
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.vertical, EBPSpacing.sm)

                WorkflowNextActionBanner(action: nextAction) { target in
                    workflowRouter.navigate(to: target, handoffMessage: nextAction.title)
                }
                .padding(.horizontal, EBPSpacing.md)
                .padding(.bottom, EBPSpacing.sm)

                bidToInvoiceBar

                // ── Summary Bar ───────────────────────────────────────────
                summaryBar

                // ── Filter Chips ──────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: EBPSpacing.xs) {
                        ForEach(InvoiceFilter.allCases, id: \.rawValue) { filter in
                            let count: Int = {
                                switch filter {
                                case .all:     return allInvoices.count
                                case .overdue: return allInvoices.filter { $0.isOverdue }.count
                                default:       return allInvoices.filter { $0.status == filter.rawValue }.count
                                }
                            }()
                            FilterChip(title: filter.label, count: count, isSelected: selectedFilter == filter, action: {
                                withAnimation { selectedFilter = filter }
                            })
                        }
                    }
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.vertical, EBPSpacing.sm)
                }

                Divider()

                // ── Invoice List ──────────────────────────────────────────
                if filteredInvoices.isEmpty {
                    Spacer()
                    EBPEmptyState(
                        icon: "doc.text.fill",
                        title: "No Invoices",
                        subtitle: "Create your first invoice from a completed job."
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: EBPSpacing.sm) {
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: VerticalScrollOffsetKey.self,
                                        value: geo.frame(in: .named("invoicingScroll")).minY
                                    )
                            }
                            .frame(height: 0)

                            // Overdue alert
                            let overdueCount = allInvoices.filter { $0.isOverdue }.count
                            if overdueCount > 0 && selectedFilter != .overdue {
                                overdueAlert(count: overdueCount)
                            }

                            ForEach(filteredInvoices) { invoice in
                                invoiceCard(invoice)
                            }
                        }
                        .padding(EBPSpacing.md)
                    }
                    .coordinateSpace(name: "invoicingScroll")
                    .onPreferenceChange(VerticalScrollOffsetKey.self) { offset in
                        workflowRouter.setDockCompact(offset < -30, for: .more)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Invoicing")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search invoices…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateInvoice = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showCreateInvoice) {
                CreateInvoiceSheet()
            }
            .sheet(item: $selectedInvoice) { invoice in
                InvoiceDetailSheet(invoice: invoice)
            }
        }
    }

    // MARK: - Summary Bar

    private var bidToInvoiceBar: some View {
        HStack(spacing: EBPSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Signed Bid Handoff")
                    .font(.subheadline.weight(.bold))
                Text("\(signedBidsReadyForInvoicing.count) ready for invoicing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                if signedBidsReadyForInvoicing.isEmpty {
                    Text("No signed bids ready")
                } else {
                    ForEach(signedBidsReadyForInvoicing.prefix(8)) { bid in
                        Button {
                            createInvoiceFromSignedBid(bid)
                        } label: {
                            Label(
                                bid.client?.displayName.isEmpty == false
                                    ? "\(bid.client!.displayName) · \(bid.bidNumber)"
                                    : (bid.bidNumber.isEmpty ? "Signed Bid" : bid.bidNumber),
                                systemImage: "doc.text.fill"
                            )
                        }
                    }
                }
            } label: {
                Label("Create from Bid", systemImage: "arrow.triangle.branch")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.vertical, 10)
                    .background(signedBidsReadyForInvoicing.isEmpty ? Color.gray.opacity(0.5) : EBPColor.accent,
                                in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            }
            .disabled(signedBidsReadyForInvoicing.isEmpty)
        }
        .padding(EBPSpacing.md)
        .background(Color(.secondarySystemBackground))
    }

    private var summaryBar: some View {
        let totalOutstanding = allInvoices
            .filter { !["PAID", "VOID"].contains($0.status) }
            .reduce(Decimal(0)) { $0 + $1.balanceDue }
        let totalPaid = allInvoices
            .filter { $0.status == "PAID" }
            .reduce(Decimal(0)) { $0 + $1.totalAmount }
        let overdue = allInvoices.filter { $0.isOverdue }
        let overdueAmount = overdue.reduce(Decimal(0)) { $0 + $1.balanceDue }

        return HStack(spacing: 0) {
            summaryCell(
                value: totalOutstanding.formatted(.currency(code: "USD")),
                label: "Outstanding",
                color: EBPColor.primary
            )
            Divider().frame(height: 36)
            summaryCell(
                value: overdueAmount.formatted(.currency(code: "USD")),
                label: "Overdue",
                color: EBPColor.error
            )
            Divider().frame(height: 36)
            summaryCell(
                value: totalPaid.formatted(.currency(code: "USD")),
                label: "Collected",
                color: EBPColor.success
            )
        }
        .padding(.vertical, EBPSpacing.sm)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Overdue Alert

    private func overdueAlert(count: Int) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(EBPColor.error)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) overdue invoice\(count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EBPColor.error)
                Text("Follow up to collect outstanding payments")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { selectedFilter = .overdue }
            } label: {
                Text("View")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(EBPColor.error, in: Capsule())
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.error.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.md)
                .strokeBorder(EBPColor.error.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Invoice Card

    private func invoiceCard(_ invoice: Invoice) -> some View {
        Button {
            selectedInvoice = invoice
        } label: {
            VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(invoice.invoiceNumber)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(statusColor(invoice))
                        Text(invoice.client?.displayName ?? "No Client")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EBPColor.onSurface)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(invoice.totalAmount, format: .currency(code: "USD"))
                            .font(.subheadline.weight(.black))
                        EBPBadge(text: displayStatus(invoice), color: statusColor(invoice))
                    }
                }

                HStack(spacing: EBPSpacing.md) {
                    Label("Issued: \(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("Due: \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(invoice.isOverdue ? EBPColor.error : .secondary)
                }

                // Balance due
                if invoice.balanceDue > 0 && invoice.balanceDue != invoice.totalAmount {
                    HStack {
                        Text("Paid: \(invoice.amountPaid, format: .currency(code: "USD"))")
                            .font(.caption)
                            .foregroundStyle(EBPColor.success)
                        Spacer()
                        Text("Balance: \(invoice.balanceDue, format: .currency(code: "USD"))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(invoice.isOverdue ? EBPColor.error : EBPColor.primary)
                    }
                }

                HStack {
                    let risk = EpoxyAIWorkflowAdvisor.invoiceCollectionRisk(invoice)
                    Text("Collection risk: \(risk)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(risk >= 60 ? EBPColor.secondary : EBPColor.success)
                    Spacer()
                }

                // Stripe link status
                if !invoice.stripePaymentLinkUrl.isEmpty {
                    HStack(spacing: EBPSpacing.xs) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(EBPColor.tertiary)
                        Text("Payment link active")
                            .font(.caption2)
                            .foregroundStyle(EBPColor.tertiary)
                    }
                }
            }
            .padding(EBPSpacing.md)
            .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            .ebpShadowSubtle()
            .overlay(
                invoice.isOverdue
                    ? RoundedRectangle(cornerRadius: EBPRadius.md)
                        .strokeBorder(EBPColor.error.opacity(0.3), lineWidth: 1)
                    : nil
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func displayStatus(_ invoice: Invoice) -> String {
        if invoice.isOverdue { return "Overdue" }
        switch invoice.status {
        case "DRAFT":   return "Draft"
        case "SENT":    return "Sent"
        case "VIEWED":  return "Viewed"
        case "PARTIAL": return "Partial"
        case "PAID":    return "Paid"
        case "VOID":    return "Void"
        default:        return invoice.status.capitalized
        }
    }

    private func statusColor(_ invoice: Invoice) -> Color {
        WorkflowStatusPalette.invoice(invoice.status, isOverdue: invoice.isOverdue)
    }

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func createInvoiceFromSignedBid(_ bid: Bid) {
        let invoice = Invoice()
        invoice.invoiceNumber = "INV-\(Int.random(in: 10001...99999))"
        invoice.status = "DRAFT"
        invoice.issueDate = Date()
        invoice.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        invoice.client = bid.client
        invoice.subtotal = bid.totalPrice
        invoice.taxRate = bid.taxRate
        invoice.taxAmount = bid.taxAmount
        invoice.totalAmount = bid.totalPrice + bid.taxAmount
        invoice.notes = "SOURCE_BID:\(bid.bidNumber)\nGenerated from signed bid workflow"

        if bid.lineItems.isEmpty {
            let li = InvoiceLineItem()
            li.itemDescription = bid.title.isEmpty ? "Epoxy Installation" : bid.title
            li.quantity = 1
            li.unitPrice = bid.totalPrice
            li.amount = bid.totalPrice
            li.sortOrder = 0
            modelContext.insert(li)
            invoice.lineItems.append(li)
        } else {
            for (idx, bidItem) in bid.lineItems.enumerated() {
                let li = InvoiceLineItem()
                li.itemDescription = bidItem.itemDescription
                li.quantity = bidItem.quantity
                li.unitPrice = bidItem.unitPrice
                li.amount = bidItem.amount
                li.sortOrder = idx
                modelContext.insert(li)
                invoice.lineItems.append(li)
            }
        }

        modelContext.insert(invoice)
        try? modelContext.save()
        selectedInvoice = invoice
        workflowRouter.navigate(to: .settings, handoffMessage: "Invoice drafted from signed bid")
    }
}
