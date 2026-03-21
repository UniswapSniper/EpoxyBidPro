import SwiftUI
import SwiftData
import RoomPlan

// ─── PipelineView ─────────────────────────────────────────────────────────────
// Unified Leads + Bids + Clients view with segmented control.

struct PipelineView: View {

    enum Segment: String, CaseIterable {
        case leads = "Leads"
        case bids  = "Bids"
        case clients = "Clients"
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var workflowRouter: WorkflowRouter

    @Query(sort: \Lead.createdAt, order: .reverse) private var allLeads: [Lead]
    @Query(sort: \Bid.createdAt, order: .reverse) private var allBids: [Bid]
    @Query(sort: \Client.firstName) private var allClients: [Client]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var allMeasurements: [Measurement]

    @State private var segment: Segment = .leads
    @State private var searchText = ""

    // Leads state
    @State private var showAddLead = false
    @State private var selectedLead: Lead? = nil

    // Clients state
    @State private var showAddClient = false
    @State private var selectedClient: Client? = nil

    // Bids state
    @State private var isPresentingNewBid = false
    @State private var isPresentingScan = false
    @State private var selectedBid: Bid? = nil
    @State private var measurementForBidBuilder: Measurement? = nil
    @State private var sortOrder: SortOrder = .newestFirst

    enum SortOrder: String, CaseIterable {
        case newestFirst  = "Newest First"
        case highestValue = "Highest Value"
        case clientName   = "Client Name"
        case status       = "Status"
    }

    // MARK: - Computed

    private var openPipelineValue: Double {
        allLeads
            .filter { !["WON", "LOST"].contains($0.status) }
            .reduce(0.0) { $0 + $1.estimatedValue }
    }

    private var searchPrompt: String {
        switch segment {
        case .leads: return "Search leads…"
        case .bids:  return "Search bids…"
        case .clients: return "Search clients…"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                EBPDynamicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: EBPSpacing.md) {
                        pipelineHeader

                        Picker("View", selection: $segment) {
                            ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, EBPSpacing.md)

                        Group {
                            switch segment {
                            case .leads: 
                                PipelineLeadsView(
                                    allLeads: allLeads,
                                    searchText: searchText,
                                    selectedLead: $selectedLead,
                                    segment: $segment
                                )
                            case .bids:  
                                PipelineBidsView(
                                    allBids: allBids,
                                    allMeasurements: allMeasurements,
                                    searchText: searchText,
                                    sortOrder: sortOrder,
                                    selectedBid: $selectedBid,
                                    isPresentingNewBid: $isPresentingNewBid,
                                    isPresentingScan: $isPresentingScan,
                                    measurementForBidBuilder: $measurementForBidBuilder
                                )
                            case .clients:
                                PipelineClientsView(
                                    allClients: allClients,
                                    searchText: searchText,
                                    selectedClient: $selectedClient,
                                    showAddClient: $showAddClient
                                )
                            }
                        }
                        .id(segment)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .animation(EBPAnimation.sectionSwitch, value: segment)

                        Spacer(minLength: 80)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: searchPrompt)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if segment == .leads || segment == .clients {
                            Button { showAddLead = true } label: {
                                Label("New Lead", systemImage: "person.badge.plus")
                            }
                            Button { showAddClient = true } label: {
                                Label("New Client", systemImage: "person.crop.circle.badge.plus")
                            }
                        } else {
                            Button { isPresentingNewBid = true } label: {
                                Label("New Bid Manually", systemImage: "doc.text.fill")
                            }
                            Button { isPresentingScan = true } label: {
                                Label("Precision Scan", systemImage: "ruler.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(EBPColor.accent)
                            .ebpNeonGlow(radius: 4, intensity: 0.5)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    if segment == .leads {
                        NavigationLink {
                            CRMInsightsView(allLeads: allLeads, allClients: allClients)
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                    } else if segment == .bids {
                        bidSortMenu
                    }
                }
            }
            .sheet(isPresented: $showAddLead) { AddLeadSheet() }
            .sheet(isPresented: $showAddClient) { AddClientSheet() }
            .sheet(item: $selectedLead) { lead in LeadDetailSheet(lead: lead) }
            .sheet(item: $selectedClient) { client in ClientDetailSheet(client: client) }
            .fullScreenCover(isPresented: $isPresentingNewBid) { BidBuilderView() }
            .fullScreenCover(isPresented: $isPresentingScan) {
                if #available(iOS 16.0, *), RoomCaptureSession.isSupported {
                    AutoScanView()
                } else {
                    ScanView()
                }
            }
            .fullScreenCover(item: $measurementForBidBuilder) { measurement in
                BidBuilderView(initialMeasurement: measurement)
            }
            .navigationDestination(item: $selectedBid) { bid in BidDetailView(bid: bid) }
        }
    }

    // MARK: - Pipeline Header

    private var pipelineHeader: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.md) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pipeline")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Leads, clients, proposals & follow-ups")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(EBPColor.accent)
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.md))
            }

            HStack(spacing: EBPSpacing.sm) {
                pipelinePill(value: "\(allLeads.count)", label: "Leads", tint: EBPColor.accent)
                pipelinePill(value: "\(allBids.count)", label: "Bids", tint: .blue)
                pipelinePill(value: formatCurrency(openPipelineValue), label: "Open", tint: EBPColor.success)
            }
        }
        .padding(EBPSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: EBPRadius.lg)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: EBPRadius.lg)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, EBPSpacing.md)
        .padding(.top, EBPSpacing.xs)
    }

    private func pipelinePill(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private var bidSortMenu: some View {
        Menu {
            ForEach(SortOrder.allCases, id: \.self) { order in
                Button {
                    withAnimation(EBPAnimation.smooth) { sortOrder = order }
                } label: {
                    if sortOrder == order {
                        Label(order.rawValue, systemImage: "checkmark")
                    } else {
                        Text(order.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }
}

// MARK: - PipelineLeadsView

struct PipelineLeadsView: View {
    let allLeads: [Lead]
    let searchText: String
    @Binding var selectedLead: Lead?
    @Binding var segment: PipelineView.Segment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workflowRouter: WorkflowRouter

    private var filteredLeads: [Lead] {
        guard !searchText.isEmpty else { return allLeads }
        let lower = searchText.lowercased()
        return allLeads.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.company.lowercased().contains(lower)
        }
    }

    private var actionableLeads: [Lead] {
        allLeads
            .filter { !["WON", "LOST"].contains($0.status) }
            .sorted { EpoxyAIWorkflowAdvisor.followUpPriorityScore($0) > EpoxyAIWorkflowAdvisor.followUpPriorityScore($1) }
            .prefix(4)
            .map { $0 }
    }

    private var overdueFollowUps: Int {
        allLeads.filter { ($0.followUpDate ?? .distantFuture) < Date() && !["WON", "LOST"].contains($0.status) }.count
    }

    var body: some View {
        VStack(spacing: EBPSpacing.md) {
            // Summary stats
            let newCount = allLeads.filter { $0.status == "NEW" }.count
            let wonCount = allLeads.filter { $0.status == "WON" }.count
            let overdue  = overdueFollowUps

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: EBPSpacing.sm) {
                EBPStatCard(title: "Total Leads",  value: "\(allLeads.count)", icon: "person.2.fill",                    tint: EBPColor.accent)
                EBPStatCard(title: "New",          value: "\(newCount)",       icon: "sparkles",                         tint: .blue)
                EBPStatCard(title: "Won",          value: "\(wonCount)",       icon: "checkmark.seal.fill",              tint: EBPColor.success)
                EBPStatCard(title: overdue > 0 ? "Overdue Follow-ups" : "Leads",
                            value: overdue > 0 ? "\(overdue)" : "\(allLeads.count)",
                            icon: overdue > 0 ? "calendar.badge.exclamationmark" : "person.fill",
                            tint: overdue > 0 ? EBPColor.warning : EBPColor.primary,
                            isAlert: overdue > 0)
            }

            // AI follow-up queue
            if !actionableLeads.isEmpty {
                VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                    Label("AI Follow-Up Queue", systemImage: "brain")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)

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
                                advanceLead(lead)
                            } label: {
                                Text("Done")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(EBPColor.accent, in: Capsule())
                            }
                            .buttonStyle(.pressScale)
                        }
                        .padding(EBPSpacing.sm)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                        .onTapGesture { selectedLead = lead }
                    }
                }
                .padding(EBPSpacing.md)
                .ebpGlassmorphism(cornerRadius: EBPRadius.md)
            }

            // Kanban columns
            ForEach(CRMLeadStage.allCases) { stage in
                kanbanColumn(stage: stage)
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.xl)
        .sheet(item: $selectedLead) { lead in LeadDetailSheet(lead: lead) }
    }

    private func kanbanColumn(stage: CRMLeadStage) -> some View {
        let leads = filteredLeads.filter { $0.status == stage.rawValue }
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
                VStack(spacing: EBPSpacing.xs) {
                    Image(systemName: "tray").font(.caption.weight(.semibold)).foregroundStyle(stage.color.opacity(0.8))
                    Text("No leads").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(height: 56).frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: EBPRadius.sm)
                    .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4])))
            } else {
                ForEach(leads) { lead in
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
                                    Label("Move to \(s.label)", systemImage: "arrow.right.circle")
                                }
                            }
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
            }
        }
        .padding(EBPSpacing.sm)
        .ebpGlassmorphism(cornerRadius: EBPRadius.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func moveLead(_ lead: Lead, to stage: CRMLeadStage) {
        lead.status = stage.rawValue
        if stage == .won { lead.convertedAt = Date() }
        try? modelContext.save()
    }

    private func advanceLead(_ lead: Lead) {
        AppHaptics.trigger(.medium)
        let previousStatus = lead.status
        switch lead.status {
        case "NEW":        lead.status = "CONTACTED"
        case "CONTACTED":  lead.status = "SITE_VISIT"
        case "SITE_VISIT": lead.status = "BID_SENT"
        default: break
        }
        lead.followUpDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())
        try? modelContext.save()
        if previousStatus == "SITE_VISIT" || lead.status == "BID_SENT" {
            workflowRouter.navigate(to: .pipeline, handoffMessage: "Lead ready for proposal — opening Pipeline")
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - PipelineBidsView

struct PipelineBidsView: View {
    let allBids: [Bid]
    let allMeasurements: [Measurement]
    let searchText: String
    let sortOrder: PipelineView.SortOrder
    @Binding var selectedBid: Bid?
    @Binding var isPresentingNewBid: Bool
    @Binding var isPresentingScan: Bool
    @Binding var measurementForBidBuilder: Measurement?

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @StateObject private var vm = BidViewModel()

    @State private var selectedFilter: BidViewModel.BidStatusFilter = .all

    private var latestMeasurement: Measurement? { allMeasurements.first }

    private var filteredBids: [Bid] {
        var result = allBids
        if selectedFilter != .all {
            result = result.filter { $0.status == (selectedFilter.apiStatus ?? "") }
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

    var body: some View {
        VStack(spacing: EBPSpacing.sm) {
            // Summary bar
            let total   = allBids.reduce(Decimal(0)) { $0 + $1.totalPrice }
            let signed  = allBids.filter { $0.status == "SIGNED" }.count
            let pending = allBids.filter { ["SENT", "VIEWED"].contains($0.status) }.count

            HStack(spacing: 0) {
                summaryCell(value: "\(allBids.count)", label: "Total")
                Divider().frame(height: 36)
                summaryCell(value: "\(pending)", label: "Pending", color: .orange)
                Divider().frame(height: 36)
                summaryCell(value: "\(signed)",  label: "Signed",  color: .green)
                Divider().frame(height: 36)
                summaryCell(value: total.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US"))), label: "Pipeline", color: EBPColor.accent)
            }
            .ebpGlassmorphism(cornerRadius: 0)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EBPSpacing.sm) {
                    ForEach(BidViewModel.BidStatusFilter.allCases) { filter in
                        let count = filter == .all ? allBids.count : allBids.filter { $0.status == (filter.apiStatus ?? "") }.count
                        FilterChip(title: filter.rawValue, count: count, isSelected: selectedFilter == filter) {
                            withAnimation(EBPAnimation.sectionSwitch) { selectedFilter = filter }
                        }
                    }
                }
                .padding(.horizontal, EBPSpacing.md)
                .padding(.vertical, EBPSpacing.sm)
            }

            // Bid list
            if filteredBids.isEmpty {
                ContentUnavailableView {
                    Label(selectedFilter == .all ? "No Bids Yet" : "No \(selectedFilter.rawValue) Bids",
                          systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(selectedFilter == .all ? "Tap + to create your first bid." : "No bids match the \"\(selectedFilter.rawValue)\" filter.")
                } actions: {
                    if selectedFilter == .all {
                        Button("Create First Bid") { isPresentingNewBid = true }
                            .buttonStyle(.borderedProminent)
                            .tint(EBPColor.accent)
                            .foregroundStyle(.black)
                    } else {
                        Button("Show All") { selectedFilter = .all }
                    }
                }
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
                                Button(role: .destructive) { vm.deleteBid(bid, context: modelContext) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { Task { await vm.cloneBid(bid, context: modelContext) } } label: {
                                    Label("Clone", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }
                .padding(.bottom, EBPSpacing.md)
            }
        }
        .navigationDestination(item: $selectedBid) { bid in BidDetailView(bid: bid) }
        .fullScreenCover(isPresented: $isPresentingNewBid) { BidBuilderView() }
        .fullScreenCover(item: $measurementForBidBuilder) { BidBuilderView(initialMeasurement: $0) }
    }

    private func summaryCell(value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PipelineClientsView

struct PipelineClientsView: View {
    let allClients: [Client]
    let searchText: String
    @Binding var selectedClient: Client?
    @Binding var showAddClient: Bool

    private var filteredClients: [Client] {
        guard !searchText.isEmpty else { return Array(allClients) }
        let lower = searchText.lowercased()
        return allClients.filter {
            $0.displayName.lowercased().contains(lower) ||
            $0.company.lowercased().contains(lower) ||
            $0.email.lowercased().contains(lower)
        }
    }

    var body: some View {
        VStack(spacing: EBPSpacing.md) {
            let thisMonthClients = allClients.filter {
                Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month)
            }.count

            HStack(spacing: EBPSpacing.sm) {
                EBPStatCard(title: "Clients", value: "\(allClients.count)", icon: "person.2.fill",  tint: EBPColor.accent)
                EBPStatCard(title: "New",     value: "\(thisMonthClients)", icon: "plus.circle.fill", tint: EBPColor.success)
            }

            LazyVStack(spacing: EBPSpacing.sm) {
                if filteredClients.isEmpty {
                    EBPEmptyState(
                        icon: "person.2.slash",
                        title: "No Clients Yet",
                        subtitle: "Clients will appear here once added."
                    )
                    .padding(.top, EBPSpacing.xl)
                } else {
                    ForEach(filteredClients) { client in
                        Button { selectedClient = client } label: {
                            HStack(spacing: EBPSpacing.md) {
                                ZStack {
                                    Circle().fill(EBPColor.primaryGradient).frame(width: 44, height: 44)
                                    Text(String(client.displayName.prefix(1)).uppercased())
                                        .font(.headline.weight(.bold)).foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(client.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                                    HStack(spacing: EBPSpacing.xs) {
                                        if !client.company.isEmpty {
                                            Text(client.company).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Text("• \(client.clientType.capitalized)").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    let bidCount = client.bids.count
                                    Text("\(bidCount) bid\(bidCount == 1 ? "" : "s")").font(.caption.weight(.semibold)).foregroundStyle(EBPColor.primary)
                                    let total = client.bids.reduce(Decimal(0)) { $0 + $1.totalPrice }
                                    if total > 0 {
                                        Text(total, format: .currency(code: "USD")).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(EBPSpacing.md)
                            .ebpGlassmorphism(cornerRadius: EBPRadius.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, EBPSpacing.md)
        .padding(.bottom, EBPSpacing.xl)
        .sheet(item: $selectedClient) { client in ClientDetailSheet(client: client) }
    }
}

// MARK: - CRM Insights (navigated from toolbar)

struct CRMInsightsView: View {
    let allLeads: [Lead]
    let allClients: [Client]

    private var wonLeads: Int { allLeads.filter { $0.status == "WON" }.count }
    private var decidedLeads: Int { allLeads.filter { ["WON", "LOST"].contains($0.status) }.count }
    private var winRate: Int { decidedLeads > 0 ? Int(Double(wonLeads) / Double(decidedLeads) * 100) : 0 }

    private var averageDaysToClose: Int {
        let closed = allLeads.filter { $0.status == "WON" && $0.convertedAt != nil }
        guard !closed.isEmpty else { return 0 }
        let totalDays = closed.reduce(0.0) {
            $0 + ($1.convertedAt?.timeIntervalSince($1.createdAt) ?? 0) / 86400
        }
        return Int(totalDays / Double(closed.count))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: EBPSpacing.md) {
                HStack(spacing: EBPSpacing.md) {
                    insightCard(value: "\(winRate)%", label: "Win Rate", icon: "trophy.fill", tint: EBPColor.gold)
                    insightCard(value: "\(averageDaysToClose)d", label: "Avg Close", icon: "clock.fill", tint: .blue)
                }

                HStack(spacing: EBPSpacing.md) {
                    insightCard(value: "\(allClients.count)", label: "Clients", icon: "person.2.fill", tint: EBPColor.accent)
                    let monthLeads = allLeads.filter {
                        Calendar.current.isDate($0.createdAt, equalTo: Date(), toGranularity: .month)
                    }.count
                    insightCard(value: "\(monthLeads)", label: "New This Month", icon: "arrow.up.right", tint: EBPColor.success)
                }

                sourceBreakdown
            }
            .padding(EBPSpacing.md)
        }
        .navigationTitle("Pipeline Insights")
        .navigationBarTitleDisplayMode(.inline)
        .background(EBPDynamicBackground())
    }

    private func insightCard(value: String, label: String, icon: String, tint: Color) -> some View {
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
                Text(value).font(.title3.weight(.black))
                Text(label).font(.caption2).foregroundStyle(.secondary)
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
            Text("Lead Sources")
                .font(.headline)

            if sources.isEmpty {
                Text("No lead data yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            }
        }
    }
}
