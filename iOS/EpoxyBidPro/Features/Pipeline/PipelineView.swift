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
                        .foregroundStyle(EBPColor.onSurface)
                    Text("Leads, clients, proposals & follow-ups")
                        .font(.caption)
                        .foregroundStyle(EBPColor.onSurfaceVariant)
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
                pipelinePill(value: "\(allBids.count)", label: "Bids", tint: EBPColor.primary)
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
                .foregroundStyle(EBPColor.onSurfaceVariant)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(EBPColor.onSurface.opacity(0.05), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
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

// PipelineLeadsView, PipelineBidsView, and PipelineClientsView are in their own files.

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
                    insightCard(value: "\(averageDaysToClose)d", label: "Avg Close", icon: "clock.fill", tint: EBPColor.primary)
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
