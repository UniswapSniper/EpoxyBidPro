import SwiftUI
import SwiftData

// ─── BidsView ─────────────────────────────────────────────────────────────────
// Primary bid management screen.
// Shows all bids with filter chips, search, and quick-action swipe gestures.

struct BidsView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bid.createdAt, order: .reverse) private var allBids: [Bid]

    // MARK: - View Model

    @StateObject private var vm = BidViewModel()

    // MARK: - State

    @State private var isPresentingNewBid = false
    @State private var searchText = ""
    @State private var selectedFilter: BidViewModel.BidStatusFilter = .all
    @State private var selectedBid: Bid? = nil

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

        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryBar
                filterChips
                bidList
            }
            .navigationTitle("Bids & Proposals")
            .searchable(text: $searchText, prompt: "Search bid number, client, title…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingNewBid = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    sortMenu
                }
            }
            .sheet(isPresented: $isPresentingNewBid) {
                newBidSheet
            }
            .navigationDestination(item: $selectedBid) { bid in
                BidDetailView(bid: bid)
            }
        }
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
            summaryCell(value: total.formatted(.currency(code: "USD")), label: "Pipeline", color: EBPColor.primary)
        }
        .padding(.vertical, EBPSpacing.sm)
        .background(Color(.secondarySystemBackground))
    }

    private func summaryCell(value: String, label: String, color: Color = .primary) -> some View {
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
                        withAnimation(.easeInOut(duration: 0.2)) {
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
            List {
                ForEach(filteredBids) { bid in
                    Button {
                        selectedBid = bid
                    } label: {
                        BidCardView(bid: bid)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if bid.status == "DRAFT" {
                            Button {
                                selectedBid = bid
                            } label: {
                                Label("Send", systemImage: "paperplane.fill")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
            .listStyle(.plain)
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
                    .tint(EBPColor.primary)
            } else {
                Button("Show All") { selectedFilter = .all }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            Button("Newest First") {}     // default — already sorted desc
            Button("Highest Value") {}
            Button("Client Name") {}
            Button("Status") {}
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - New Bid Sheet

    private var newBidSheet: some View {
        NavigationStack {
            Form {
                Section("Bid Details") {
                    Text("New bid creation will be connected to the Bid Builder in a future sprint.")
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Create Draft Bid") {
                        let draft = vm.createDraftBid(context: modelContext)
                        isPresentingNewBid = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            selectedBid = draft
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .tint(EBPColor.primary)
                }
            }
            .navigationTitle("New Bid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresentingNewBid = false }
                }
            }
        }
    }
}

// ─── FilterChip ───────────────────────────────────────────────────────────────

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, EBPSpacing.md)
            .padding(.vertical, EBPSpacing.sm)
            .background(isSelected ? EBPColor.primary : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
