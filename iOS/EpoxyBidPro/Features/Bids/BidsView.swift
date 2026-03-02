import SwiftUI
import SwiftData

// ─── BidsView ─────────────────────────────────────────────────────────────────
// Primary bid management screen.
// Shows all bids with filter chips, search, and quick-action swipe gestures.

struct BidsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var workflowRouter: WorkflowRouter
    @Query(sort: \Lead.createdAt, order: .reverse) private var workflowLeads: [Lead]
    @Query(sort: \Bid.createdAt, order: .reverse) private var allBids: [Bid]
    @Query(sort: \Job.createdAt, order: .reverse) private var workflowJobs: [Job]
    @Query(sort: \Invoice.createdAt, order: .reverse) private var workflowInvoices: [Invoice]
    @Query(sort: \Measurement.scanDate, order: .reverse) private var allMeasurements: [Measurement]

    // MARK: - View Model

    @StateObject private var vm = BidViewModel()

    // MARK: - State

    @State private var isPresentingNewBid = false
    @State private var isPresentingScan = false
    @State private var searchText = ""
    @State private var selectedFilter: BidViewModel.BidStatusFilter = .all
    @State private var selectedBid: Bid? = nil
    @State private var measurementForBidBuilder: Measurement? = nil

    // MARK: - Computed

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
        case .newestFirst:
            result.sort { $0.createdAt > $1.createdAt }
        case .highestValue:
            result.sort { ($0.totalPrice as Decimal) > ($1.totalPrice as Decimal) }
        case .clientName:
            result.sort { ($0.client?.displayName ?? "") < ($1.client?.displayName ?? "") }
        case .status:
            let order = ["SIGNED", "SENT", "VIEWED", "DRAFT", "DECLINED", "EXPIRED"]
            result.sort { (order.firstIndex(of: $0.status) ?? 99) < (order.firstIndex(of: $1.status) ?? 99) }
        }

        return result
    }

    private var latestMeasurement: Measurement? {
        allMeasurements.first
    }

    private var workflowSnapshot: WorkflowKPISnapshot {
        WorkflowKPIService.snapshot(
            leads: workflowLeads,
            bids: allBids,
            jobs: workflowJobs,
            invoices: workflowInvoices,
            measurements: allMeasurements
        )
    }

    private var nextAction: WorkflowNextAction {
        WorkflowKPIService.nextBestAction(from: workflowSnapshot)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                EBPDynamicBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: VerticalScrollOffsetKey.self,
                                    value: geo.frame(in: .named("bidsScroll")).minY
                                )
                        }
                        .frame(height: 0)

                        WorkflowKPIBanner(snapshot: workflowSnapshot)
                            .padding(.horizontal, EBPSpacing.md)
                            .padding(.bottom, EBPSpacing.sm)

                        WorkflowNextActionBanner(action: nextAction) { target in
                            workflowRouter.navigate(to: target, handoffMessage: nextAction.title)
                        }
                        .padding(.horizontal, EBPSpacing.md)
                        .padding(.bottom, EBPSpacing.sm)

                        workflowCommandDeck
                        summaryBar
                        filterChips
                        bidList

                        Spacer(minLength: 120)
                    }
                }
                .coordinateSpace(name: "bidsScroll")
                .onPreferenceChange(VerticalScrollOffsetKey.self) { offset in
                    workflowRouter.setDockCompact(offset < -30, for: .bids)
                }
            }
            .navigationTitle("Bids & Proposals")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search bid number, client, title…")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewBid = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(EBPColor.accent)
                            .ebpNeonGlow(radius: 4, intensity: 0.5)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
            }
            .fullScreenCover(isPresented: $isPresentingNewBid) {
                BidBuilderView()
            }
            .fullScreenCover(isPresented: $isPresentingScan) {
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

    // MARK: - Workflow Command Deck

    private var workflowCommandDeck: some View {
        VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            HStack(spacing: EBPSpacing.xs) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(EBPColor.accent)
                Text("Estimation Workflow")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Scan → AI → Bid")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }

            if let latestMeasurement {
                VStack(alignment: .leading, spacing: 6) {
                    Text(latestMeasurement.label.isEmpty ? "Latest measurement" : latestMeasurement.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    HStack {
                        Label("\(Int(latestMeasurement.totalSqFt)) sq ft", systemImage: "ruler.fill")
                            .font(.caption2)
                            .foregroundStyle(EBPColor.accent)
                        Spacer()
                        Text(latestMeasurement.scanDate.relativeFormatted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(aiEstimateHint(for: latestMeasurement.totalSqFt))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }
                .padding(EBPSpacing.sm)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            } else {
                Text("Run a LiDAR/AR scan first to auto-fill measurements and AI pricing guidance.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(EBPSpacing.sm)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
            }

            HStack(spacing: EBPSpacing.sm) {
                Button {
                    isPresentingScan = true
                } label: {
                    Label("Scan Space", systemImage: "ruler")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(EBPColor.accent, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)

                Button {
                    if let latestMeasurement {
                        measurementForBidBuilder = latestMeasurement
                        workflowRouter.navigate(to: .bids, handoffMessage: "Prefilling bid from latest scan")
                    } else {
                        isPresentingNewBid = true
                    }
                } label: {
                    Label(latestMeasurement == nil ? "New Bid" : "Build From Scan", systemImage: "doc.text.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
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

    // MARK: - Summary Bar

    private var summaryBar: some View {
        let total = allBids.reduce(Decimal(0)) { $0 + $1.totalPrice }
        let signed = allBids.filter { $0.status == "SIGNED" }.count
        let pending = allBids.filter { ["SENT", "VIEWED"].contains($0.status) }.count

        return HStack(spacing: 0) {
            summaryCell(value: "\(allBids.count)", label: "Total")
            Divider().frame(height: 36)
            summaryCell(value: "\(pending)", label: "Pending", color: .orange)
            Divider().frame(height: 36)
            summaryCell(value: "\(signed)", label: "Signed", color: .green)
            Divider().frame(height: 36)
            summaryCell(value: total.formatted(.currency(code: "USD")), label: "Pipeline", color: EBPColor.accent)
        }
        .ebpGlassmorphism(cornerRadius: 0)
    }

    private func summaryCell(value: String, label: String, color: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EBPSpacing.sm) {
                ForEach(BidViewModel.BidStatusFilter.allCases) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        count: count(for: filter),
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(EBPAnimation.sectionSwitch) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, EBPSpacing.md)
            .padding(.vertical, EBPSpacing.sm)
        }
    }

    private func count(for filter: BidViewModel.BidStatusFilter) -> Int {
        filter == .all
            ? allBids.count
            : allBids.filter { $0.status == (filter.apiStatus ?? "") }.count
    }

    // MARK: - Bid List

    @ViewBuilder
    private var bidList: some View {
        if filteredBids.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: EBPSpacing.sm) {
                ForEach(filteredBids) { bid in
                    Button {
                        selectedBid = bid
                    } label: {
                        BidCardView(bid: bid)
                    }
                    .buttonStyle(.pressScale)
                    .padding(.horizontal, EBPSpacing.md)
                    .contextMenu {
                        if bid.status == "DRAFT" {
                            Button {
                                selectedBid = bid
                            } label: {
                                Label("Send", systemImage: "paperplane.fill")
                            }
                        }

                        Button(role: .destructive) {
                            vm.deleteBid(bid, context: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            Task { await vm.cloneBid(bid, context: modelContext) }
                        } label: {
                            Label("Clone", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .padding(.bottom, EBPSpacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                selectedFilter == .all ? "No Bids Yet" : "No \(selectedFilter.rawValue) Bids",
                systemImage: "doc.text.magnifyingglass"
            )
        } description: {
            Text(selectedFilter == .all
                ? "Tap + to create your first bid."
                : "No bids match the \"\(selectedFilter.rawValue)\" filter.")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sort Menu

    @State private var sortOrder: SortOrder = .newestFirst

    enum SortOrder: String, CaseIterable {
        case newestFirst  = "Newest First"
        case highestValue = "Highest Value"
        case clientName   = "Client Name"
        case status       = "Status"
    }

    private var sortMenu: some View {
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

    private func aiEstimateHint(for sqFt: Double) -> String {
        "AI hint: \(EpoxyAIWorkflowAdvisor.bidGuidance(forSqFt: sqFt))"
    }


}

// ─── FilterChip ───────────────────────────────────────────────────────────────

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            AppHaptics.trigger(.light)
            action()
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.black.opacity(0.20) : EBPColor.surface.opacity(0.8))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, EBPSpacing.md)
            .padding(.vertical, 9)
            .background(isSelected ? EBPColor.accent : EBPColor.surface)
            .foregroundStyle(isSelected ? .black : .white)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? EBPColor.accent : EBPColor.silver.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(EBPAnimation.snappy, value: isSelected)
    }
}

