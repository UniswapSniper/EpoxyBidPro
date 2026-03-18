import SwiftUI
import SwiftData

// ─── Create Invoice Sheet ────────────────────────────────────────────────────
// Auto-generates from completed jobs or allows manual creation.

struct CreateInvoiceSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Job> { $0.statusRaw == "COMPLETE" }) private var completedJobs: [Job]
    @Query(sort: \Client.firstName) private var clients: [Client]

    @State private var createFromJob = true
    @State private var selectedJob: Job? = nil
    @State private var selectedClient: Client? = nil
    @State private var dueDays = 30
    @State private var depositPercent = 0.0
    @State private var notes = ""
    @State private var includeStripeLink = true

    var body: some View {
        NavigationStack {
            Form {
                // From job toggle
                if !completedJobs.isEmpty {
                    Section {
                        Toggle("Auto-Generate from Job", isOn: $createFromJob)
                            .tint(EBPColor.primary)

                        if createFromJob {
                            Picker("Select Job", selection: $selectedJob) {
                                Text("Select…").tag(nil as Job?)
                                ForEach(completedJobs) { job in
                                    Text("\(job.jobNumber) — \(job.title.isEmpty ? "Untitled" : job.title)")
                                        .tag(job as Job?)
                                }
                            }
                        }
                    } header: {
                        Text("Source")
                    } footer: {
                        Text("Invoicing from a completed job auto-fills line items, pricing, and client info.")
                    }
                }

                // Client (manual)
                if !createFromJob {
                    Section("Client") {
                        Picker("Client", selection: $selectedClient) {
                            Text("None").tag(nil as Client?)
                            ForEach(clients) { c in
                                Text(c.displayName).tag(c as Client?)
                            }
                        }
                    }
                }

                // Terms
                Section("Payment Terms") {
                    Picker("Due In", selection: $dueDays) {
                        Text("Upon Receipt").tag(0)
                        Text("Net 15").tag(15)
                        Text("Net 30").tag(30)
                        Text("Net 45").tag(45)
                        Text("Net 60").tag(60)
                    }

                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        HStack {
                            Text("Deposit Required")
                                .font(.subheadline)
                            Spacer()
                            Text(depositPercent > 0 ? "\(Int(depositPercent))%" : "None")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EBPColor.primary)
                        }
                        Slider(value: $depositPercent, in: 0...50, step: 5)
                            .tint(EBPColor.primary)
                    }
                }

                // Payment
                Section("Payment Collection") {
                    Toggle("Generate Stripe Payment Link", isOn: $includeStripeLink)
                        .tint(.purple)

                    if includeStripeLink {
                        HStack(spacing: EBPSpacing.sm) {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(.purple)
                            Text("Clients can pay via credit card, Apple Pay, or bank transfer.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }

                // Preview
                if let job = selectedJob, createFromJob {
                    Section("Preview") {
                        let total = job.revenue
                        let deposit = total * Decimal(depositPercent / 100)
                        LabeledContent("Subtotal") {
                            Text(total, format: .currency(code: "USD"))
                        }
                        if depositPercent > 0 {
                            LabeledContent("Deposit (\(Int(depositPercent))%)") {
                                Text(deposit, format: .currency(code: "USD"))
                                    .foregroundStyle(EBPColor.primary)
                            }
                        }
                        LabeledContent("Due Date") {
                            Text(Calendar.current.date(byAdding: .day, value: dueDays, to: Date())?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                        }
                    }
                }

                // Create
                Section {
                    Button {
                        createInvoice()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Create Invoice", systemImage: "doc.text.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(createFromJob && selectedJob == nil)
                }
            }
            .navigationTitle("New Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedJob) { _, job in
                if let job {
                    selectedClient = job.client
                }
            }
        }
    }

    private func createInvoice() {
        let inv = Invoice()
        inv.invoiceNumber = "INV-\(Int.random(in: 10001...99999))"
        inv.issueDate = Date()
        inv.dueDate = Calendar.current.date(byAdding: .day, value: dueDays, to: Date()) ?? Date()
        inv.notes = notes

        if createFromJob, let job = selectedJob {
            inv.client = job.client
            inv.job = job

            // Auto-fill from job/bid
            let total = job.revenue
            inv.subtotal = total
            inv.taxAmount = total * Decimal(0.08)
            inv.totalAmount = total + inv.taxAmount
            inv.depositAmount = total * Decimal(depositPercent / 100)

            // Mark job as invoiced
            job.status = .invoiced

            // Generate line items from bid
            if let bid = job.bid {
                for (idx, bidItem) in bid.lineItems.enumerated() {
                    let li = InvoiceLineItem()
                    li.itemDescription = bidItem.itemDescription
                    li.quantity = bidItem.quantity
                    li.unitPrice = bidItem.unitPrice
                    li.amount = bidItem.amount
                    li.sortOrder = idx
                    inv.lineItems.append(li)
                    modelContext.insert(li)
                }
            } else {
                // Create single line item
                let li = InvoiceLineItem()
                li.itemDescription = job.title.isEmpty ? "Epoxy Floor Installation" : job.title
                li.quantity = 1
                li.unitPrice = total
                li.amount = total
                li.sortOrder = 0
                inv.lineItems.append(li)
                modelContext.insert(li)
            }
        } else {
            inv.client = selectedClient
        }

        // Generate Stripe payment link (mock for now)
        if includeStripeLink {
            let amountCents = NSDecimalNumber(decimal: inv.totalAmount * 100).intValue
            inv.stripePaymentLinkUrl = "https://pay.epoxybidpro.com/i/\(inv.invoiceNumber.lowercased())?amount=\(amountCents)"
        }

        modelContext.insert(inv)
        try? modelContext.save()
        dismiss()
    }
}

// ─── Invoice Detail Sheet ────────────────────────────────────────────────────

struct InvoiceDetailSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var invoice: Invoice

    @State private var showRecordPayment = false
    @State private var paymentAmount = ""
    @State private var paymentMethod = "STRIPE"
    @State private var copiedLink = false

    private let paymentMethods = ["STRIPE", "CHECK", "CASH", "ZELLE", "VENMO"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: EBPSpacing.lg) {

                    // ── Hero ──────────────────────────────────────────────
                    invoiceHero

                    // ── Client ────────────────────────────────────────────
                    clientSection

                    // ── Line Items ────────────────────────────────────────
                    lineItemsSection

                    // ── Payment Summary ───────────────────────────────────
                    paymentSummary

                    // ── Stripe Link ───────────────────────────────────────
                    if !invoice.stripePaymentLinkUrl.isEmpty {
                        stripeLinkSection
                    }

                    // ── Record Payment ────────────────────────────────────
                    if invoice.balanceDue > 0 {
                        recordPaymentSection
                    }

                    // ── Actions ───────────────────────────────────────────
                    actionsSection
                }
                .padding(EBPSpacing.md)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(invoice.invoiceNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var invoiceHero: some View {
        VStack(spacing: EBPSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.invoiceNumber)
                        .font(.title3.weight(.black))
                    EBPBadge(text: displayStatus, color: statusColor)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(invoice.totalAmount, format: .currency(code: "USD"))
                        .font(.title.weight(.black))
                    if invoice.balanceDue > 0 && invoice.balanceDue != invoice.totalAmount {
                        Text("Due: \(invoice.balanceDue, format: .currency(code: "USD"))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(invoice.isOverdue ? EBPColor.danger : EBPColor.primary)
                    }
                }
            }

            HStack {
                Label("Issued \(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("Due \(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(invoice.isOverdue ? EBPColor.danger : .secondary)
            }

            if invoice.isOverdue {
                let daysOverdue = Calendar.current.dateComponents([.day], from: invoice.dueDate, to: Date()).day ?? 0
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(EBPColor.danger)
                    Text("\(daysOverdue) day\(daysOverdue == 1 ? "" : "s") overdue")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(EBPColor.danger)
                    Spacer()
                }
                .padding(EBPSpacing.sm)
                .background(EBPColor.danger.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
    }

    // MARK: - Client

    private var clientSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(EBPColor.primary)
                Text("Client")
                    .font(.headline)
            }

            if let client = invoice.client {
                Text(client.displayName)
                    .font(.subheadline.weight(.semibold))
                if !client.email.isEmpty {
                    Text(client.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !client.phone.isEmpty {
                    Text(client.phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No client assigned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EBPSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(EBPColor.primary)
                Text("Line Items")
                    .font(.headline)
                Spacer()
                Text("\(invoice.lineItems.count) item\(invoice.lineItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let items = invoice.lineItems.sorted(by: { $0.sortOrder < $1.sortOrder })
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.itemDescription)
                            .font(.caption.weight(.medium))
                        Text("Qty: \(item.quantity, specifier: "%.1f") × \(item.unitPrice, format: .currency(code: "USD"))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.amount, format: .currency(code: "USD"))
                        .font(.caption.weight(.bold))
                }
                .padding(.vertical, 4)
            }

            Divider()

            HStack {
                Text("Subtotal")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(invoice.subtotal, format: .currency(code: "USD"))
                    .font(.caption.weight(.bold))
            }
            HStack {
                Text("Tax (\(NSDecimalNumber(decimal: invoice.taxRate * 100).intValue)%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(invoice.taxAmount, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Total")
                    .font(.subheadline.weight(.black))
                Spacer()
                Text(invoice.totalAmount, format: .currency(code: "USD"))
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(EBPColor.primary)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Payment Summary

    private var paymentSummary: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(EBPColor.primary)
                Text("Payment")
                    .font(.headline)
            }

            HStack {
                Text("Amount Paid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(invoice.amountPaid, format: .currency(code: "USD"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.success)
            }
            HStack {
                Text("Balance Due")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(invoice.balanceDue, format: .currency(code: "USD"))
                    .font(.caption.weight(.black))
                    .foregroundStyle(invoice.isOverdue ? EBPColor.danger : EBPColor.primary)
            }

            if invoice.depositAmount > 0 {
                HStack {
                    Text("Deposit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    EBPBadge(
                        text: invoice.depositPaid ? "Received" : "Pending",
                        color: invoice.depositPaid ? EBPColor.success : EBPColor.warning
                    )
                    Text(invoice.depositAmount, format: .currency(code: "USD"))
                        .font(.caption.weight(.semibold))
                }
            }

            if !invoice.paymentMethod.isEmpty {
                HStack {
                    Text("Method")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(invoice.paymentMethod.capitalized)
                        .font(.caption.weight(.medium))
                }
            }

            // Progress bar
            let paidFraction = invoice.totalAmount > 0
                ? NSDecimalNumber(decimal: invoice.amountPaid / invoice.totalAmount).doubleValue
                : 0
            ProgressView(value: min(paidFraction, 1.0))
                .tint(invoice.status == .paid ? EBPColor.success : EBPColor.primary)
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Stripe Link

    private var stripeLinkSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.purple)
                Text("Payment Link")
                    .font(.headline)
            }

            Text(invoice.stripePaymentLinkUrl)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)

            HStack(spacing: EBPSpacing.sm) {
                Button {
                    UIPasteboard.general.string = invoice.stripePaymentLinkUrl
                    withAnimation { copiedLink = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { copiedLink = false }
                    }
                } label: {
                    Label(copiedLink ? "Copied!" : "Copy Link", systemImage: copiedLink ? "checkmark" : "doc.on.clipboard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(copiedLink ? EBPColor.success : .purple, in: Capsule())
                }

                ShareLink(item: invoice.stripePaymentLinkUrl) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.purple.opacity(0.10), in: Capsule())
                }
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Record Payment

    private var recordPaymentSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Image(systemName: "banknote.fill")
                    .foregroundStyle(EBPColor.success)
                Text("Record Payment")
                    .font(.headline)
            }

            HStack(spacing: EBPSpacing.sm) {
                TextField("Amount", text: $paymentAmount)
                    .keyboardType(.decimalPad)
                    .padding(EBPSpacing.sm)
                    .font(.headline)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: EBPRadius.sm))

                Picker("", selection: $paymentMethod) {
                    ForEach(paymentMethods, id: \.self) { m in
                        Text(m.capitalized).tag(m)
                    }
                }
                .pickerStyle(.menu)
            }

            Button {
                recordPayment()
            } label: {
                HStack {
                    Spacer()
                    Label("Record", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(EBPColor.success, in: RoundedRectangle(cornerRadius: EBPRadius.md))
            }
            .disabled(paymentAmount.isEmpty)

            // Quick pay full amount button
            Button {
                paymentAmount = "\(NSDecimalNumber(decimal: invoice.balanceDue).doubleValue)"
            } label: {
                Text("Pay full balance: \(invoice.balanceDue, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(EBPColor.primary)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: EBPSpacing.sm) {
            if invoice.status == .draft {
                EBPButton(title: "Send Invoice", icon: "paperplane.fill", style: .primary) {
                    invoice.status = .sent
                    try? modelContext.save()
                }
            }

            if invoice.status != .void && invoice.status != .paid {
                Button(role: .destructive) {
                    invoice.status = .void
                    try? modelContext.save()
                } label: {
                    HStack {
                        Spacer()
                        Label("Void Invoice", systemImage: "xmark.circle")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .foregroundStyle(EBPColor.danger)
                    .background(EBPColor.danger.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.md))
                }
            }
        }
    }

    // MARK: - Helpers

    private func recordPayment() {
        guard let amount = Decimal(string: paymentAmount), amount > 0 else { return }
        invoice.amountPaid += amount
        invoice.paymentMethod = paymentMethod

        if invoice.balanceDue <= 0 {
            invoice.status = .paid
            invoice.paidDate = Date()
        } else {
            invoice.status = .partial
        }

        try? modelContext.save()
        paymentAmount = ""
    }

    private var displayStatus: String {
        if invoice.isOverdue { return "Overdue" }
        return invoice.status.label
    }

    private var statusColor: Color {
        if invoice.isOverdue { return EBPColor.danger }
        switch invoice.status {
        case .draft:   return .secondary
        case .sent:    return .blue
        case .viewed:  return .indigo
        case .partial: return EBPColor.warning
        case .paid:    return EBPColor.success
        case .void:    return .gray
        case .overdue: return EBPColor.danger
        }
    }
}
