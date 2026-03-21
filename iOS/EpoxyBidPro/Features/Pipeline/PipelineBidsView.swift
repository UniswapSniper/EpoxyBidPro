import SwiftUI
import SwiftData

struct PipelineBidsView: View {
    @Environment(\.modelContext) private var modelContext
    
    var allBids: [Bid]
    var allMeasurements: [Measurement]
    var searchText: String
    var sortOrder: PipelineView.SortOrder
    
    @Binding var selectedBid: Bid?
    @Binding var isPresentingNewBid: Bool
    @Binding var isPresentingScan: Bool
    @Binding var measurementForBidBuilder: Measurement?
    
    @StateObject private var bidVM = BidViewModel()
    @State private var selectedFilter: BidViewModel.BidStatusFilter = .all

    private var latestMeasurement: Measurement? { allMeasurements.first }
    private var pendingBids: [Bid] { allBids.filter { ["SENT", "VIEWED"].contains($0.status) } }
    private var draftBids: [Bid] { allBids.filter { $0.status == "DRAFT" } }
    private var signedBids: [Bid] { allBids.filter { $0.status == "SIGNED" } }

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
        VStack(spacing: 0) {
            if allBids.isEmpty {
                emptyHeroState
            } else {
                workflowCommandDeck
                bidsSummaryBar
                bidsFilterChips

                if filteredBids.isEmpty {
                    EBPEmptyState(
                        icon: "doc.text.magnifyingglass",
                        title: selectedFilter == .all ? "No Bids Yet" : "No \(selectedFilter.rawValue) Bids",
                        subtitle: selectedFilter == .all
                            ? "Create a proposal or build one from your latest scan."
                            : "No bids match the current filter.",
                        action: selectedFilter == .all
                            ? ("Create First Bid", { isPresentingNewBid = true })
                            : ("Show All", { selectedFilter = .all })
                    )
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.top, EBPSpacing.xl)
                } else {
                    LazyVStack(spacing: EBPSpacing.sm) {
                        ForEach(filteredBids) { bid in
                            Button { selectedBid = bid } label: {
                                BidCardView(bid: bid)
                            }
                            .buttonStyle(.pressScale)
                            .padding(.horizontal, EBPSpacing.md)
                            .contextMenu {
                                if bid.status == "DRAFT" {
                                    Button { selectedBid = bid } label: {
                                        Label("Send", systemImage: "paperplane.fill")
                                    }
                                }
                                Button(role: .destructive) {
                                    bidVM.deleteBid(bid, context: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    Task { await bidVM.cloneBid(bid, context: modelContext) }
                                } label: {
                                    Label("Clone", systemImage: "doc.on.doc")
                                }
                            }
                        }
                    }
                    .padding(.bottom, EBPSpacing.md)
                }
            }
        }
    }

    private var emptyHeroState: some View {
        VStack(spacing: EBPSpacing.lg) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 60))
                .foregroundStyle(EBPColor.accent)
                .padding(.bottom, EBPSpacing.sm)
            
            Text("No Bids Yet")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            
            Text("Create a standard proposal or scan a room to automatically build one using AI.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, EBPSpacing.lg)
            
            VStack(spacing: EBPSpacing.sm) {
                Button { isPresentingScan = true } label: {
                    Label("Precision Scan Space", systemImage: "ruler.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(EBPColor.accent, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                }
                .buttonStyle(.plain)
                
                Button { isPresentingNewBid = true } label: {
                    Label("Create Bid Manually", systemImage: "doc.text.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: EBPRadius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, EBPSpacing.xl)
            .padding(.top, EBPSpacing.md)
        }
        .padding(.vertical, 60)
    }

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

            HStack(spacing: EBPSpacing.sm) {
                Button {
                    if let latestMeasurement {
                        measurementForBidBuilder = latestMeasurement
                    } else {
                        isPresentingNewBid = true
                    }
                } label: {
                    Label(latestMeasurement == nil ? "New Bid" : "Build From Scan", systemImage: "doc.text.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(EBPColor.accent, in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                }
                .buttonStyle(.plain)

                Button { isPresentingScan = true } label: {
                    Label("Precision Scan", systemImage: "ruler")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
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
        return HStack(spacing: 0) {
            bidSummaryCell(value: "\(allBids.count)", label: "Total")
            Divider().frame(height: 36)
            bidSummaryCell(value: "\(pendingBids.count)", label: "Pending", color: .orange)
            Divider().frame(height: 36)
            bidSummaryCell(value: "\(signedBids.count)", label: "Signed", color: .green)
            Divider().frame(height: 36)
            bidSummaryCell(value: total.formatted(.currency(code: "USD")), label: "Pipeline", color: EBPColor.accent)
        }
        .ebpGlassmorphism(cornerRadius: 0)
    }

    private var bidsFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EBPSpacing.sm) {
                ForEach(BidViewModel.BidStatusFilter.allCases) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        count: filter == .all ? allBids.count : allBids.filter { $0.status == (filter.apiStatus ?? "") }.count,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(EBPAnimation.sectionSwitch) { selectedFilter = filter }
                    }
                }
            }
            .padding(.horizontal, EBPSpacing.md)
            .padding(.vertical, EBPSpacing.sm)
        }
    }

    private func bidSummaryCell(value: String, label: String, color: Color = .white) -> some View {
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
}
