import SwiftUI
import SwiftData

// ─── CRMView ──────────────────────────────────────────────────────────────────
// Full local CRM with SwiftData-driven Kanban pipeline, client profiles, and
// lead management. Replaces the analytics-only stub.

struct CRMView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(WorkflowRouter.self) private var workflowRouter
    @Query(sort: \Lead.createdAt, order: .reverse) private var allLeads: [Lead]
    @Query(sort: \Bid.createdAt, order: .reverse) private var workflowBids: [Bid]
    @Query(sort: \Job.createdAt, order: .reverse) private var workflowJobs: [Job]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var workflowInvoices: [Invoice]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var workflowMeasurements: [Measurement]
    @Query(sort: \Client.firstName) private var allClients: [Client]

    @State private var selectedSection: CRMSection = .pipeline
    @State private var showAddLead = false
    @State private var showAddClient = false
    @State private var searchText = ""
    @State private var selectedLead: Lead? = nil
    @State private var selectedClient: Client? = nil
    @State private var draggedLeadId: UUID? = nil
    @State private var lostReasonLead: Lead? = nil
    @State private var lostReasonText: String = "Price"

    enum CRMSection: String, CaseIterable {
        case pipeline = "pipeline"
        case clients  = "crm.clients"
        case insights = "insights"
        
        var localizedName: String {
            NSLocalizedString(self.rawValue, comment: "")
        }
    }

    private var workflowSnapshot: WorkflowKPISnapshot {
        WorkflowKPIService.snapshot(
            leads: allLeads,
            bids: workflowBids,
            jobs: workflowJobs,
            invoices: workflowInvoices,
            measurements: workflowMeasurements
        )
    }

    private var nextAction: WorkflowNextAction {
        WorkflowKPIService.nextBestAction(from: workflowSnapshot)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EBPDynamicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EBPSpacing.md) {
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: VerticalScrollOffsetKey.self,
                                    value: geo.frame(in: .named("crmMainScroll")).minY
                                )
                        }
                        .frame(height: 0)

                        crmHeader

                        WorkflowKPIBanner(snapshot: workflowSnapshot)
                            .padding(.horizontal, EBPSpacing.md)

                        WorkflowNextActionBanner(action: nextAction) { target in
                            workflowRouter.navigate(to: target, handoffMessage: nextAction.title)
                        }
                        .padding(.horizontal, EBPSpacing.md)

                        Picker("Section", selection: $selectedSection) {
                            ForEach(CRMSection.allCases, id: \.self) { Text($0.localizedName).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, EBPSpacing.md)
                        .padding(.top, EBPSpacing.xs)

                        Group {
                            switch selectedSection {
                            case .pipeline: pipelineView
                            case .clients:  clientsView
                            case .insights: insightsView
                            }
                        }
                        .id(selectedSection)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .animation(EBPAnimation.sectionSwitch, value: selectedSection)

                        Spacer(minLength: 120)
                    }
                }
                .coordinateSpace(name: "crmMainScroll")
                .onPreferenceChange(VerticalScrollOffsetKey.self) { offset in
                    workflowRouter.setDockCompact(offset < -30, for: .crm)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: NSLocalizedString("search.crm", comment: ""))
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddLead = true
                        } label: {
                            Label(NSLocalizedString("new.lead", comment: ""), systemImage: "person.badge.plus")
                        }
                        Button {
                            showAddClient = true
                        } label: {
                            Label(NSLocalizedString("new.client", comment: ""), systemImage: "person.crop.circle.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(EBPColor.accent)
                            .ebpNeonGlow(radius: 4, intensity: 0.5)
                    }
                }
            }
            .sheet(isPresented: $showAddLead) {
                AddLeadSheet()
            }
            .sheet(isPresented: $showAddClient) {
                AddClientSheet()
            }
            .sheet(item: $selectedLead) { lead in
                LeadDetailSheet(lead: lead)
            }
            .sheet(item: $selectedClient) { client in
                ClientDetailSheet(client: client)
            }
            .sheet(item: $lostReasonLead) { lead in
                LostReasonSheet(lead: lead, selectedReason: $lostReasonText) {
                    moveLead(lead, to: .lost, reason: lostReasonText)
                    lostReasonLead = nil
                }
            }
        }
    }

    private var crmHeader: some View {
        let openPipelineValue = allLeads
            .filter { $0.status != .won && $0.status != .lost }
            .reduce(0.0) { $0 + $1.estimatedValue }

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CRM")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Leads, clients, and follow-up health")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(EBPColor.accent)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
            }

            HStack(spacing: EBPSpacing.sm) {
                EBPBadge(text: "\(allLeads.count) leads", color: EBPColor.accent)
                EBPBadge(text: "\(allClients.count) clients", color: EBPColor.primary)
                EBPBadge(text: formatCurrency(openPipelineValue), color: EBPColor.success)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.lg)
        .padding(.horizontal, EBPSpacing.md)
        .padding(.top, EBPSpacing.xs)
    }

    // MARK: - Pipeline (Kanban)

    private var pipelineView: some View {
        VStack(spacing: EBPSpacing.md) {
            pipelineSummaryBar
            followUpAutomationQueue

            ForEach(CRMLeadStage.allCases) { stage in
                kanbanColumn(stage: stage)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.xl)
    }

    private var followUpAutomationQueue: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Label("AI Follow-Up Queue", systemImage: "brain")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(actionableLeads.count) next")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if actionableLeads.isEmpty {
                Text("No urgent follow-ups. Your pipeline is clear right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, EBPSpacing.xs)
            } else {
                ForEach(actionableLeads) { lead in
                    HStack(spacing: EBPSpacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lead.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(followUpSuggestion(for: lead))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(2)

                            Text("Close probability: \(EpoxyAIWorkflowAdvisor.leadCloseProbability(lead))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(EBPColor.accent)
                        }

                        Spacer()

                        Button {
                            completeFollowUp(lead)
                        } label: {
                            Text("Done")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(EBPColor.accent, in: Capsule())
                        }
                        .buttonStyle(.pressScale)

                        Button {
                            snoozeFollowUp(lead)
                        } label: {
                            Text("+1d")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.pressScale)
                    }
                    .padding(EBPSpacing.sm)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                    .onTapGesture {
                        selectedLead = lead
                    }
                }
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .animation(EBPAnimation.sectionSwitch, value: actionableLeads.count)
    }

    private var pipelineSummaryBar: some View {
        let newCount = allLeads.filter { $0.status == .new }.count
        let totalValue = allLeads
            .filter { $0.status != .won && $0.status != .lost }
            .reduce(0.0) { $0 + $1.estimatedValue }
        let wonCount = allLeads.filter { $0.status == .won }.count
        let overdue = overdueFollowUps

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: EBPSpacing.sm) {
            EBPStatCard(
                title: NSLocalizedString("total.leads", comment: ""),
                value: "\(allLeads.count)",
                icon: "person.2.fill",
                tint: EBPColor.accent
            )

            EBPStatCard(
                title: NSLocalizedString("new", comment: ""),
                value: "\(newCount)",
                icon: "sparkles",
                tint: .blue
            )

            EBPStatCard(
                title: NSLocalizedString("won", comment: ""),
                value: "\(wonCount)",
                icon: "checkmark.seal.fill",
                tint: EBPColor.success
            )

            EBPStatCard(
                title: overdue > 0 ? NSLocalizedString("overdue.followups", comment: "") : NSLocalizedString("pipeline", comment: ""),
                value: overdue > 0 ? "\(overdue)" : formatCurrency(totalValue),
                icon: overdue > 0 ? "calendar.badge.exclamationmark" : "dollarsign.circle.fill",
                tint: overdue > 0 ? EBPColor.warning : EBPColor.primary,
                isAlert: overdue > 0
            )
        }
    }

    private func kanbanColumn(stage: CRMLeadStage) -> some View {
        let leads = filteredLeads(for: stage)
        let totalValue = leads.reduce(0.0) { $0 + $1.estimatedValue }

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.xs) {
                Circle()
                    .fill(stage.color)
                    .frame(width: 8, height: 8)
                Text(stage.label)
                    .font(.subheadline.weight(.bold))
                Spacer()
                EBPBadge(text: "\(leads.count)", color: stage.color)
            }

            if totalValue > 0 {
                Text(formatCurrency(totalValue))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stage.color)
            }

            if leads.isEmpty {
                emptyColumnPlaceholder(stage: stage)
            } else {
                ForEach(leads) { lead in
                    leadCard(lead, stage: stage)
                }
            }
        }
        .padding(EBPSpacing.sm)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func leadCard(_ lead: Lead, stage: CRMLeadStage) -> some View {
        Button {
            selectedLead = lead
        } label: {
            VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                HStack {
                    Text(lead.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    if lead.estimatedValue > 0 {
                        Text(formatCurrency(lead.estimatedValue))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(stage.color)
                    }
                }

                if !lead.company.isEmpty {
                    Text(lead.company)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: EBPSpacing.xs) {
                    if !lead.source.isEmpty {
                        EBPPillTag(text: lead.source.capitalized, color: .secondary)
                    }

                    if let followUp = lead.followUpDate {
                        HStack(spacing: 2) {
                            Image(systemName: followUp < Date() ? "exclamationmark.triangle.fill" : "calendar")
                                .font(.system(size: 8))
                                .foregroundStyle(followUp < Date() ? EBPColor.danger : .secondary)
                            Text(followUp.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(followUp < Date() ? EBPColor.danger : .secondary)
                        }
                    }
                }
            }
            .padding(EBPSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ebpGlassmorphism(cornerRadius: EBPRadius.sm)
        }
        .buttonStyle(.plain)
        .contextMenu {
            ForEach(CRMLeadStage.allCases) { s in
                if s.rawValue != lead.statusRaw {
                    Button {
                        if s == .lost {
                            lostReasonText = "Price"
                            lostReasonLead = lead
                        } else {
                            moveLead(lead, to: s)
                        }
                    } label: {
                        Label(String(format: NSLocalizedString("move.to", comment: ""), s.label), systemImage: "arrow.right.circle")
                    }
                }
            }
            Divider()
            Button {
                convertLeadToClient(lead)
            } label: {
                Label("Convert to Client", systemImage: "person.crop.circle.badge.checkmark")
            }
            Divider()
            Button(role: .destructive) {
                modelContext.delete(lead)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func emptyColumnPlaceholder(stage: CRMLeadStage) -> some View {
        VStack(spacing: EBPSpacing.xs) {
            Image(systemName: "tray")
                .font(.caption.weight(.semibold))
                .foregroundStyle(stage.color.opacity(0.8))
            Text(NSLocalizedString("no.leads", comment: ""))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
            .frame(height: 56)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
    }

    // MARK: - Clients View

    private var clientsView: some View {
        VStack(spacing: EBPSpacing.md) {
            let thisMonthClients = allClients.filter {
                Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month)
            }.count

            HStack(spacing: EBPSpacing.sm) {
                EBPStatCard(
                    title: NSLocalizedString("crm.clients", comment: ""),
                    value: "\(allClients.count)",
                    icon: "person.2.fill",
                    tint: EBPColor.accent
                )
                EBPStatCard(
                    title: NSLocalizedString("new", comment: ""),
                    value: "\(thisMonthClients)",
                    icon: "plus.circle.fill",
                    tint: EBPColor.success
                )
            }

            LazyVStack(spacing: EBPSpacing.sm) {
                if filteredClients.isEmpty {
                    EBPEmptyState(
                        icon: "person.2.slash",
                        title: NSLocalizedString("no.clients.yet", comment: ""),
                        subtitle: NSLocalizedString("no.clients.hint", comment: "")
                    )
                    .padding(.top, EBPSpacing.xl)
                } else {
                    ForEach(filteredClients) { client in
                        clientRow(client)
                    }
                }
            }
        }
        .padding(EBPSpacing.md)
        .padding(.bottom, EBPSpacing.xl)
    }

    private func clientRow(_ client: Client) -> some View {
        Button {
            selectedClient = client
        } label: {
            HStack(spacing: EBPSpacing.md) {
                ZStack {
                    Circle()
                        .fill(EBPColor.primaryGradient)
                        .frame(width: 44, height: 44)
                    Text(String(client.displayName.prefix(1)).uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(client.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: EBPSpacing.xs) {
                        if !client.company.isEmpty {
                            Text(client.company)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("• \(client.clientType.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    let bidCount = client.bids.count
                    Text(String(format: NSLocalizedString("count.bids", comment: ""), bidCount, bidCount == 1 ? "" : "s"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EBPColor.primary)

                    let total = client.bids.reduce(Decimal(0)) { $0 + $1.totalPrice }
                    if total > 0 {
                        Text(total, format: .currency(code: "USD"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(EBPSpacing.md)
            .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Insights View

    private var insightsView: some View {
        VStack(spacing: EBPSpacing.md) {
            let wonLeads = allLeads.filter { $0.status == .won }.count
            let decidedLeads = allLeads.filter { $0.status == .won || $0.status == .lost }.count
            let winRate = decidedLeads > 0 ? Int(Double(wonLeads) / Double(decidedLeads) * 100) : 0

            HStack(spacing: EBPSpacing.md) {
                insightStatCard(value: "\(winRate)%", label: NSLocalizedString("win.rate", comment: ""), icon: "trophy.fill", tint: EBPColor.gold)
                let avgDays = averageDaysToClose
                insightStatCard(value: "\(avgDays)d", label: NSLocalizedString("avg.close", comment: ""), icon: "clock.fill", tint: .blue)
            }
            .ebpHPadding()

            HStack(spacing: EBPSpacing.md) {
                insightStatCard(value: "\(allClients.count)", label: NSLocalizedString("crm.clients", comment: ""), icon: "person.2.fill", tint: EBPColor.accent)
                let monthLeads = allLeads.filter {
                    Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month)
                }.count
                insightStatCard(value: "\(monthLeads)", label: NSLocalizedString("new.lead", comment: ""), icon: "arrow.up.right", tint: EBPColor.success)
            }
            .ebpHPadding()

            sourceBreakdown

            insightCard(
                icon: "arrow.up.right.circle.fill",
                tint: EBPColor.success,
                title: NSLocalizedString("win.more.bids", comment: ""),
                body: "Follow up on 'SITE_VISIT' leads within 24 hours — data shows win rates are 3× higher."
            )
            insightCard(
                icon: "calendar.badge.exclamationmark",
                tint: EBPColor.warning,
                title: NSLocalizedString("overdue.followups", comment: ""),
                body: String(format: "You have %d leads with past-due follow-up dates. Update them now.", overdueFollowUps)
            )
            insightCard(
                icon: "star.fill",
                tint: EBPColor.gold,
                title: NSLocalizedString("reward.top.clients", comment: ""),
                body: "Your top 20% of clients generate 80% of revenue. Consider a VIP referral programme."
            )
            }
        .padding(.vertical, EBPSpacing.md)
    }

    // MARK: - Helpers

    private func filteredLeads(for stage: CRMLeadStage) -> [Lead] {
        let stageLeads = allLeads.filter { $0.statusRaw == stage.rawValue }
        if searchText.isEmpty { return stageLeads }
        let lower = searchText.lowercased()
        return stageLeads.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.company.lowercased().contains(lower)
        }
    }

    private var filteredClients: [Client] {
        if searchText.isEmpty { return Array(allClients) }
        let lower = searchText.lowercased()
        return allClients.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.company.lowercased().contains(lower) ||
            $0.email.lowercased().contains(lower)
        }
    }

    private func moveLead(_ lead: Lead, to stage: CRMLeadStage, reason: String = "") {
        lead.status = LeadStatus(rawValue: stage.rawValue) ?? .new
        if stage == .won {
            lead.convertedAt = Date()
        }
        if stage == .lost && !reason.isEmpty {
            lead.lostReason = reason
        }
        try? modelContext.save()
    }

    private func convertLeadToClient(_ lead: Lead) {
        let client = Client()
        client.firstName = lead.firstName
        client.lastName = lead.lastName
        client.email = lead.email
        client.phone = lead.phone
        client.company = lead.company
        client.address = lead.address
        client.clientType = "residential"
        modelContext.insert(client)

        lead.status = .won
        lead.convertedAt = Date()
        try? modelContext.save()
    }

    private var averageDaysToClose: Int {
        let closed = allLeads.filter { $0.status == .won && $0.convertedAt != nil }
        guard !closed.isEmpty else { return 0 }
        let totalDays = closed.reduce(0.0) {
            $0 + ($1.convertedAt?.timeIntervalSince($1.createdAt) ?? 0) / 86400
        }
        return Int(totalDays / Double(closed.count))
    }

    private var overdueFollowUps: Int {
        allLeads.filter { ($0.followUpDate ?? .distantFuture) < Date() && $0.status != .won && $0.status != .lost }.count
    }

    private var actionableLeads: [Lead] {
        allLeads
            .filter { $0.status != .won && $0.status != .lost }
            .sorted {
                EpoxyAIWorkflowAdvisor.followUpPriorityScore($0) > EpoxyAIWorkflowAdvisor.followUpPriorityScore($1)
            }
            .prefix(4)
            .map { $0 }
    }

    private func followUpSuggestion(for lead: Lead) -> String {
        EpoxyAIWorkflowAdvisor.nextBestAction(for: lead)
    }

    private func completeFollowUp(_ lead: Lead) {
        AppHaptics.trigger(.medium)

        let previousStatus = lead.status

        switch lead.status {
        case .new:
            lead.status = .contacted
        case .contacted:
            lead.status = .siteVisit
        case .siteVisit:
            lead.status = .bidSent
        default:
            break
        }

        lead.followUpDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        try? modelContext.save()

        if previousStatus == .siteVisit || lead.status == .bidSent {
            workflowRouter.navigate(
                to: .bids,
                handoffMessage: "Lead ready for proposal — opening Bids"
            )
        }
    }

    private func snoozeFollowUp(_ lead: Lead) {
        AppHaptics.trigger(.light)
        let base = lead.followUpDate ?? Date()
        lead.followUpDate = Calendar.current.date(byAdding: .day, value: 1, to: base)
        try? modelContext.save()
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func summaryCell(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightStatCard(value: String, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .fill(tint.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.black))
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
    }

    private var sourceBreakdown: some View {
        let sources = Dictionary(grouping: allLeads, by: { $0.source.isEmpty ? "Unknown" : $0.source })
            .map { (source: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text(NSLocalizedString("lead.sources", comment: ""))
                .font(.headline)
                .ebpHPadding()

            if sources.isEmpty {
                Text("No lead data yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .ebpHPadding()
            } else {
                VStack(spacing: 0) {
                    ForEach(sources.prefix(6), id: \.source) { item in
                        HStack {
                            Text(item.source.capitalized)
                                .font(.subheadline)
                            Spacer()
                            Text("\(item.count)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(EBPColor.primary)
                        }
                        .padding(.horizontal, EBPSpacing.md)
                        .padding(.vertical, 10)
                    }
                }
                .ebpGlassmorphism(cornerRadius: EBPRadius.md)
                .ebpHPadding()
            }
        }
    }

    private func insightCard(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: EBPSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .fill(tint.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .ebpHPadding()
    }
}

// ─── Lost Reason Sheet ───────────────────────────────────────────────────────

struct LostReasonSheet: View {

    let lead: Lead
    @Binding var selectedReason: String
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let reasons = ["Price", "Competitor", "Timing", "No Response", "Project Cancelled", "Other"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Lead info
                VStack(spacing: 4) {
                    Text(lead.displayName)
                        .font(.headline)
                    if !lead.company.isEmpty {
                        Text(lead.company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                // Reason picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Why was this lead lost?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(EBPColor.accent)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                selectedReason == reason
                                    ? EBPColor.accent.opacity(0.08)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                    }
                }

                Spacer()

                // Confirm
                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Mark as Lost")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: EBPRadius.md))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle("Lost Reason")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// ─── Lead Stages ─────────────────────────────────────────────────────────────

enum CRMLeadStage: String, CaseIterable, Identifiable {
    case new        = "NEW"
    case contacted  = "CONTACTED"
    case siteVisit  = "SITE_VISIT"
    case bidSent    = "BID_SENT"
    case won        = "WON"
    case lost       = "LOST"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new:       return NSLocalizedString("new", comment: "")
        case .contacted: return NSLocalizedString("contacted", comment: "")
        case .siteVisit: return NSLocalizedString("site.visit", comment: "")
        case .bidSent:   return NSLocalizedString("bid.sent", comment: "")
        case .won:       return NSLocalizedString("won", comment: "")
        case .lost:      return NSLocalizedString("lost", comment: "")
        }
    }

    var color: Color {
        WorkflowStatusPalette.lead(rawValue)
    }
}
