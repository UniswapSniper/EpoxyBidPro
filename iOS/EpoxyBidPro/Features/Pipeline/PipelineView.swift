import SwiftUI
import SwiftData

// ─── PipelineView ────────────────────────────────────────────────────────────
// Unified Leads + Bids view with segmented control.
// Merges CRMView pipeline/clients and BidsView into a single tab.

struct PipelineView: View {

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @Query(sort: \Lead.createdAt, order: .reverse) private var allLeads: [Lead]
    @Query(sort: \Bid.createdAt, order: .reverse) private var allBids: [Bid]
    @Query(sort: \Job.createdAt, order: .reverse) private var workflowJobs: [Job]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var workflowInvoices: [Invoice]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var allMeasurements: [Measurement]
    @Query(sort: \Client.firstName) private var allClients: [Client]

    @State private var selectedSegment: Segment = .leads
    @State private var showAddLead = false
    @State private var showAddClient = false
    @State private var showNewBid = false
    @State private var showScan = false
    @State private var searchText = ""
    @State private var selectedLead: Lead? = nil
    @State private var selectedClient: Client? = nil
    @State private var selectedBid: Bid? = nil
    @State private var measurementForBidBuilder: Measurement? = nil
    @State private var selectedBidFilter: BidViewModel.BidStatusFilter = .all
    @State private var sortOrder: BidSortOrder = .newestFirst

    @StateObject private var bidVM = BidViewModel()

    enum Segment: String, CaseIterable {
        case leads = "Leads"
        case bids  = "Bids"
    }

    enum BidSortOrder: String, CaseIterable {
        case newestFirst  = "Newest First"
        case highestValue = "Highest Value"
        case clientName   = "Client Name"
        case status       = "Status"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EBPDynamicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EBPSpacing.md) {
                        Picker("Segment", selection: $selectedSegment) {
                            ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, EBPSpacing.md)
                        .padding(.top, EBPSpacing.sm)

                        Group {
                            switch selectedSegment {
                            case .leads: leadsContent
                            case .bids:  bidsContent
                            }
                        }
                        .id(selectedSegment)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .animation(EBPAnimation.sectionSwitch, value: selectedSegment)

                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationTitle("Pipeline")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: selectedSegment == .leads ? "Search leads & clients…" : "Search bids…")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addMenu
                }

                if selectedSegment == .bids {
                    ToolbarItem(placement: .topBarLeading) {
                        bidSortMenu
                    }
                }

                if selectedSegment == .leads {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            CRMInsightsView(allLeads: allLeads, allClients: allClients)
                        } label: {
                            Image(systemName: "chart.bar")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddLead) { AddLeadSheet() }
            .sheet(isPresented: $showAddClient) { AddClientSheet() }
            .sheet(item: $selectedLead) { lead in LeadDetailSheet(lead: lead) }
            .sheet(item: $selectedClient) { client in ClientDetailSheet(client: client) }
            .fullScreenCover(isPresented: $showNewBid) { BidBuilderView() }
            .fullScreenCover(isPresented: $showScan) {
                if #available(iOS 16.0, *) {
                    AutoScanView()
                } else {
                    ScanView()
                }
            }
            .fullScreenCover(item: $measurementForBidBuilder) { measurement in
                BidBuilderView(initialMeasurement: measurement)
            }
            .navigationDestination(item: $selectedBid) { bid in
                BidDetailView(bid: bid)
            }
        }
    }

    // MARK: - Add Menu

    @ViewBuilder
    private var addMenu: some View {
        Menu {
            if selectedSegment == .leads {
                Button { showAddLead = true } label: {
                    Label(NSLocalizedString("new.lead", comment: ""), systemImage: "person.badge.plus")
                }
                Button { showAddClient = true } label: {
                    Label(NSLocalizedString("new.client", comment: ""), systemImage: "person.crop.circle.badge.plus")
                }
            } else {
                Button { showNewBid = true } label: {
                    Label("New Bid", systemImage: "doc.badge.plus")
                }
                Button { showScan = true } label: {
                    Label("Scan Space", systemImage: "ruler")
                }
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(EBPColor.accent)
                .ebpNeonGlow(radius: 4, intensity: 0.5)
        }
    }

    // MARK: ─ LEADS CONTENT ──────────────────────────────────────────────────

    private var leadsContent: some View {
        VStack(spacing: EBPSpacing.md) {
            pipelineSummaryBar
            followUpAutomationQueue

            ForEach(CRMLeadStage.allCases) { stage in
                kanbanColumn(stage: stage)
            }

            // Clients section
            clientsSection
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.xl)
    }

    private var pipelineSummaryBar: some View {
        let newCount = allLeads.filter { $0.status == "NEW" }.count
        let totalValue = allLeads
            .filter { !["WON", "LOST"].contains($0.status) }
            .reduce(0.0) { $0 + $1.estimatedValue }
        let wonCount = allLeads.filter { $0.status == "WON" }.count
        let overdue = overdueFollowUps

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: EBPSpacing.sm) {
            EBPStatCard(title: NSLocalizedString("total.leads", comment: ""), value: "\(allLeads.count)", icon: "person.2.fill", tint: EBPColor.accent)
            EBPStatCard(title: NSLocalizedString("new", comment: ""), value: "\(newCount)", icon: "sparkles", tint: .blue)
            EBPStatCard(title: NSLocalizedString("won", comment: ""), value: "\(wonCount)", icon: "checkmark.seal.fill", tint: EBPColor.success)
            EBPStatCard(
                title: overdue > 0 ? NSLocalizedString("overdue.followups", comment: "") : NSLocalizedString("pipeline", comment: ""),
                value: overdue > 0 ? "\(overdue)" : formatCurrency(totalValue),
                icon: overdue > 0 ? "calendar.badge.exclamationmark" : "dollarsign.circle.fill",
                tint: overdue > 0 ? EBPColor.warning : EBPColor.primary,
                isAlert: overdue > 0
            )
        }
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
                            Text(EpoxyAIWorkflowAdvisor.nextBestAction(for: lead))
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
                    .onTapGesture { selectedLead = lead }
                }
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .animation(EBPAnimation.sectionSwitch, value: actionableLeads.count)
    }

    private func kanbanColumn(stage: CRMLeadStage) -> some View {
        let leads = filteredLeads(for: stage)
        let totalValue = leads.reduce(0.0) { $0 + $1.estimatedValue }

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.xs) {
                Circle().fill(stage.color).frame(width: 8, height: 8)
                Text(stage.label).font(.subheadline.weight(.bold))
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
        Button { selectedLead = lead } label: {
            VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                HStack {
                    Text(lead.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                    Spacer()
                    if lead.estimatedValue > 0 {
                        Text(formatCurrency(lead.estimatedValue)).font(.caption2.weight(.bold)).foregroundStyle(stage.color)
                    }
                }
                if !lead.company.isEmpty {
                    Text(lead.company).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                HStack(spacing: EBPSpacing.xs) {
                    if !lead.source.isEmpty { EBPPillTag(text: lead.source.capitalized, color: .secondary) }
                    if let followUp = lead.followUpDate {
                        HStack(spacing: 2) {
                            Image(systemName: followUp < Date() ? "exclamationmark.triangle.fill" : "calendar").font(.system(size: 8)).foregroundStyle(followUp < Date() ? EBPColor.danger : .secondary)
                            Text(followUp.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(followUp < Date() ? EBPColor.danger : .secondary)
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
                if s.rawValue != lead.status {
                    Button { moveLead(lead, to: s) } label: {
                        Label(String(format: NSLocalizedString("move.to", comment: ""), s.label), systemImage: "arrow.right.circle")
                    }
                }
            }
            Divider()
            Button { convertLeadToClient(lead) } label: {
                Label("Convert to Client", systemImage: "person.crop.circle.badge.checkmark")
            }
            Divider()
            Button(role: .destructive) { modelContext.delete(lead); try? modelContext.save() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func emptyColumnPlaceholder(stage: CRMLeadStage) -> some View {
        VStack(spacing: EBPSpacing.xs) {
            Image(systemName: "tray").font(.caption.weight(.semibold)).foregroundStyle(stage.color.opacity(0.8))
            Text(NSLocalizedString("no.leads", comment: "")).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: EBPRadius.sm).strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4])))
    }

    private var clientsSection: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack {
                Text(NSLocalizedString("crm.clients", comment: ""))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(allClients.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if filteredClients.isEmpty {
                EBPEmptyState(icon: "person.2.slash", title: NSLocalizedString("no.clients.yet", comment: ""), subtitle: NSLocalizedString("no.clients.hint", comment: ""))
                    .padding(.top, EBPSpacing.md)
            } else {
                ForEach(filteredClients.prefix(10)) { client in
                    Button { selectedClient = client } label: {
                        HStack(spacing: EBPSpacing.md) {
                            ZStack {
                                Circle().fill(EBPColor.primaryGradient).frame(width: 40, height: 40)
                                Text(String(client.displayName.prefix(1)).uppercased()).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                                if !client.company.isEmpty {
                                    Text(client.company).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            let bidCount = client.bids.count
                            if bidCount > 0 {
                                Text(String(format: NSLocalizedString("count.bids", comment: ""), bidCount, bidCount == 1 ? "" : "s"))
                                    .font(.caption2.weight(.semibold)).foregroundStyle(EBPColor.primary)
                            }
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(EBPSpacing.sm)
                        .ebpGlassmorphism(cornerRadius: EBPRadius.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, EBPSpacing.md)
    }

    // MARK: ─ BIDS CONTENT ───────────────────────────────────────────────────

    private var bidsContent: some View {
        VStack(spacing: 0) {
            scanHeroButton
            workflowCommandDeck
            bidsSummaryBar
            bidsFilterChips
            bidsList
        }
    }

    private var scanHeroButton: some View {
        Button { showScan = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Garage Floor")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("LiDAR measure → instant pricing → one-tap bid")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(EBPSpacing.md)
            .background(EBPColor.heroGradient, in: RoundedRectangle(cornerRadius: EBPRadius.lg))
            .ebpShadowStrong()
        }
        .buttonStyle(.pressScale)
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.sm)
    }

    private var workflowCommandDeck: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.xs) {
                Image(systemName: "sparkles.rectangle.stack").font(.caption.weight(.bold)).foregroundStyle(EBPColor.accent)
                Text("Estimation Workflow").font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Spacer()
                Text("Scan → AI → Bid").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.65))
            }

            if let latest = latestMeasurement {
                VStack(alignment: .leading, spacing: 6) {
                    Text(latest.label.isEmpty ? "Latest measurement" : latest.label)
                        .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                    HStack {
                        Label("\(Int(latest.totalSqFt)) sq ft", systemImage: "ruler.fill").font(.caption2).foregroundStyle(EBPColor.accent)
                        Spacer()
                        Text(latest.scanDate.relativeFormatted).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("AI hint: \(EpoxyAIWorkflowAdvisor.bidGuidance(forSqFt: latest.totalSqFt))")
                        .font(.caption2).foregroundStyle(.white.opacity(0.75)).lineLimit(2)
                }
                .padding(EBPSpacing.sm)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            } else {
                Text("Run a LiDAR/AR scan first to auto-fill measurements and AI pricing guidance.")
                    .font(.caption).foregroundStyle(.white.opacity(0.75))
                    .padding(EBPSpacing.sm)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            }

            HStack(spacing: EBPSpacing.sm) {
                Button { showScan = true } label: {
                    Label("Scan Space", systemImage: "ruler")
                        .font(.caption.weight(.semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(EBPColor.accent, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)

                Button {
                    if let latest = latestMeasurement { measurementForBidBuilder = latest }
                    else { showNewBid = true }
                } label: {
                    Label(latestMeasurement == nil ? "New Bid" : "Build From Scan", systemImage: "doc.text.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(EBPColor.primaryGradient, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EBPSpacing.md)
        .ebpGlassmorphism(cornerRadius: EBPRadius.lg)
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.sm)
    }

    private var bidsSummaryBar: some View {
        let total = allBids.reduce(Decimal(0)) { $0 + $1.totalPrice }
        let signed = allBids.filter { $0.status == "SIGNED" }.count
        let pending = allBids.filter { ["SENT", "VIEWED"].contains($0.status) }.count

        return HStack(spacing: 0) {
            bidSummaryCell(value: "\(allBids.count)", label: "Total")
            Divider().frame(height: 36)
            bidSummaryCell(value: "\(pending)", label: "Pending", color: .orange)
            Divider().frame(height: 36)
            bidSummaryCell(value: "\(signed)", label: "Signed", color: .green)
            Divider().frame(height: 36)
            bidSummaryCell(value: total.formatted(.currency(code: "USD")), label: "Pipeline", color: EBPColor.accent)
        }
        .ebpGlassmorphism(cornerRadius: 0)
    }

    private func bidSummaryCell(value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var bidsFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EBPSpacing.sm) {
                ForEach(BidViewModel.BidStatusFilter.allCases) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        count: bidCount(for: filter),
                        isSelected: selectedBidFilter == filter
                    ) {
                        withAnimation(EBPAnimation.sectionSwitch) { selectedBidFilter = filter }
                    }
                }
            }
            .padding(.horizontal, EBPSpacing.md)
            .padding(.vertical, EBPSpacing.sm)
        }
    }

    @ViewBuilder
    private var bidsList: some View {
        if filteredBids.isEmpty {
            ContentUnavailableView {
                Label(selectedBidFilter == .all ? "No Bids Yet" : "No \(selectedBidFilter.rawValue) Bids", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text(selectedBidFilter == .all ? "Tap + to create your first bid." : "No bids match the \"\(selectedBidFilter.rawValue)\" filter.")
            } actions: {
                if selectedBidFilter == .all {
                    Button("Create First Bid") { showNewBid = true }
                        .buttonStyle(.borderedProminent).tint(EBPColor.accent).foregroundStyle(.black)
                } else {
                    Button("Show All") { selectedBidFilter = .all }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVStack(spacing: EBPSpacing.sm) {
                ForEach(filteredBids) { bid in
                    Button { selectedBid = bid } label: { BidCardView(bid: bid) }
                        .buttonStyle(.pressScale)
                        .padding(.horizontal, EBPSpacing.md)
                        .contextMenu {
                            if bid.status == "DRAFT" {
                                Button { selectedBid = bid } label: { Label("Send", systemImage: "paperplane.fill") }
                            }
                            Button(role: .destructive) { bidVM.deleteBid(bid, context: modelContext) } label: { Label("Delete", systemImage: "trash") }
                            Button { Task { await bidVM.cloneBid(bid, context: modelContext) } } label: { Label("Clone", systemImage: "doc.on.doc") }
                        }
                }
            }
            .padding(.bottom, EBPSpacing.md)
        }
    }

    private var bidSortMenu: some View {
        Menu {
            ForEach(BidSortOrder.allCases, id: \.self) { order in
                Button {
                    withAnimation(EBPAnimation.smooth) { sortOrder = order }
                } label: {
                    if sortOrder == order { Label(order.rawValue, systemImage: "checkmark") }
                    else { Text(order.rawValue) }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - Computed Properties

    private var latestMeasurement: Measurement? { allMeasurements.first }

    private var filteredBids: [Bid] {
        var result = Array(allBids)
        if selectedBidFilter != .all {
            result = result.filter { $0.status == (selectedBidFilter.apiStatus ?? "") }
        }
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            result = result.filter {
                $0.bidNumber.lowercased().contains(lower) ||
                $0.title.lowercased().contains(lower) ||
                ($0.client?.displayName.lowercased().contains(lower) ?? false)
            }
        }
        switch sortOrder {
        case .newestFirst:  result.sort { $0.createdAt > $1.createdAt }
        case .highestValue: result.sort { ($0.totalPrice as Decimal) > ($1.totalPrice as Decimal) }
        case .clientName:   result.sort { ($0.client?.displayName ?? "") < ($1.client?.displayName ?? "") }
        case .status:
            let order = ["SIGNED", "SENT", "VIEWED", "DRAFT", "DECLINED", "EXPIRED"]
            result.sort { (order.firstIndex(of: $0.status) ?? 99) < (order.firstIndex(of: $1.status) ?? 99) }
        }
        return result
    }

    private func bidCount(for filter: BidViewModel.BidStatusFilter) -> Int {
        filter == .all ? allBids.count : allBids.filter { $0.status == (filter.apiStatus ?? "") }.count
    }

    private func filteredLeads(for stage: CRMLeadStage) -> [Lead] {
        let stageLeads = allLeads.filter { $0.status == stage.rawValue }
        if searchText.isEmpty { return stageLeads }
        let lower = searchText.lowercased()
        return stageLeads.filter { $0.displayName.lowercased().contains(lower) || $0.company.lowercased().contains(lower) }
    }

    private var filteredClients: [Client] {
        if searchText.isEmpty { return Array(allClients) }
        let lower = searchText.lowercased()
        return allClients.filter { $0.displayName.lowercased().contains(lower) || $0.company.lowercased().contains(lower) || $0.email.lowercased().contains(lower) }
    }

    private var overdueFollowUps: Int {
        allLeads.filter { ($0.followUpDate ?? .distantFuture) < Date() && !["WON", "LOST"].contains($0.status) }.count
    }

    private var actionableLeads: [Lead] {
        allLeads
            .filter { !["WON", "LOST"].contains($0.status) }
            .sorted { EpoxyAIWorkflowAdvisor.followUpPriorityScore($0) > EpoxyAIWorkflowAdvisor.followUpPriorityScore($1) }
            .prefix(4)
            .map { $0 }
    }

    // MARK: - Actions

    private func moveLead(_ lead: Lead, to stage: CRMLeadStage) {
        lead.status = stage.rawValue
        if stage == .won { lead.convertedAt = Date() }
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
        lead.status = "WON"
        lead.convertedAt = Date()
        try? modelContext.save()
    }

    private func completeFollowUp(_ lead: Lead) {
        AppHaptics.trigger(.medium)
        switch lead.status {
        case "NEW": lead.status = "CONTACTED"
        case "CONTACTED": lead.status = "SITE_VISIT"
        case "SITE_VISIT": lead.status = "BID_SENT"
        default: break
        }
        lead.followUpDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        try? modelContext.save()
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
}

// MARK: - CRM Insights (extracted as its own view for nav push)

struct CRMInsightsView: View {
    let allLeads: [Lead]
    let allClients: [Client]

    private var wonLeads: Int { allLeads.filter { $0.status == "WON" }.count }
    private var decidedLeads: Int { allLeads.filter { ["WON", "LOST"].contains($0.status) }.count }
    private var winRate: Int { decidedLeads > 0 ? Int(Double(wonLeads) / Double(decidedLeads) * 100) : 0 }

    private var averageDaysToClose: Int {
        let closed = allLeads.filter { $0.status == "WON" && $0.convertedAt != nil }
        guard !closed.isEmpty else { return 0 }
        let totalDays = closed.reduce(0.0) { $0 + ($1.convertedAt?.timeIntervalSince($1.createdAt) ?? 0) / 86400 }
        return Int(totalDays / Double(closed.count))
    }

    private var overdueFollowUps: Int {
        allLeads.filter { ($0.followUpDate ?? .distantFuture) < Date() && !["WON", "LOST"].contains($0.status) }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: EBPSpacing.md) {
                HStack(spacing: EBPSpacing.md) {
                    insightStatCard(value: "\(winRate)%", label: NSLocalizedString("win.rate", comment: ""), icon: "trophy.fill", tint: EBPColor.gold)
                    insightStatCard(value: "\(averageDaysToClose)d", label: NSLocalizedString("avg.close", comment: ""), icon: "clock.fill", tint: .blue)
                }

                HStack(spacing: EBPSpacing.md) {
                    insightStatCard(value: "\(allClients.count)", label: NSLocalizedString("crm.clients", comment: ""), icon: "person.2.fill", tint: EBPColor.accent)
                    let monthLeads = allLeads.filter { Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month) }.count
                    insightStatCard(value: "\(monthLeads)", label: NSLocalizedString("new.lead", comment: ""), icon: "arrow.up.right", tint: EBPColor.success)
                }

                sourceBreakdown

                insightCard(icon: "arrow.up.right.circle.fill", tint: EBPColor.success, title: NSLocalizedString("win.more.bids", comment: ""),
                            body: "Follow up on 'SITE_VISIT' leads within 24 hours — data shows win rates are 3× higher.")
                insightCard(icon: "calendar.badge.exclamationmark", tint: EBPColor.warning, title: NSLocalizedString("overdue.followups", comment: ""),
                            body: String(format: "You have %d leads with past-due follow-up dates. Update them now.", overdueFollowUps))
                insightCard(icon: "star.fill", tint: EBPColor.gold, title: NSLocalizedString("reward.top.clients", comment: ""),
                            body: "Your top 20% of clients generate 80% of revenue. Consider a VIP referral programme.")
            }
            .padding(EBPSpacing.md)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("CRM Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func insightStatCard(value: String, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: EBPSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm).fill(tint.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.title3.weight(.black))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(EBPSpacing.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }

    private var sourceBreakdown: some View {
        let sources = Dictionary(grouping: allLeads, by: { $0.source.isEmpty ? "Unknown" : $0.source })
            .map { (source: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            Text(NSLocalizedString("lead.sources", comment: "")).font(.headline)
            if sources.isEmpty {
                Text("No lead data yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(sources.prefix(6), id: \.source) { item in
                        HStack {
                            Text(item.source.capitalized).font(.subheadline)
                            Spacer()
                            Text("\(item.count)").font(.subheadline.weight(.semibold)).foregroundStyle(EBPColor.primary)
                        }
                        .padding(.horizontal, EBPSpacing.md)
                        .padding(.vertical, 10)
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: EBPRadius.md))
            }
        }
    }

    private func insightCard(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: EBPSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: EBPRadius.sm).fill(tint.opacity(0.12)).frame(width: 44, height: 44)
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: EBPSpacing.xs) {
                Text(title).font(.subheadline.weight(.bold))
                Text(body).font(.caption).foregroundStyle(.secondary).lineSpacing(2)
            }
        }
        .padding(EBPSpacing.md)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: EBPRadius.md))
    }
}
