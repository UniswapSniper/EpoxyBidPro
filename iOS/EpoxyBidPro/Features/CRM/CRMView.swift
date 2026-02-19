import SwiftUI

// ─── CRMView ──────────────────────────────────────────────────────────────────
// Lead & client management with a horizontal pipeline kanban and top-client list.

struct CRMView: View {

    @StateObject private var vm = AnalyticsViewModel()
    @State private var selectedSection: CRMSection = .pipeline
    @State private var appeared = false

    enum CRMSection: String, CaseIterable {
        case pipeline = "Pipeline"
        case clients  = "Top Clients"
        case insights = "Insights"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Section Picker ─────────────────────────────────────────
                Picker("Section", selection: $selectedSection) {
                    ForEach(CRMSection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(EBPSpacing.md)
                .background(Color(.systemBackground))

                Divider()

                // ── Content ────────────────────────────────────────────────
                ZStack {
                    if vm.isLoading && vm.crmPipeline == nil {
                        ProgressView("Loading CRM…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        switch selectedSection {
                        case .pipeline:  pipelineSection
                        case .clients:   topClientsSection
                        case .insights:  insightsSection
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("CRM")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: Add lead sheet
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
        }
        .task { await vm.loadCRMPipeline() }
    }

    // MARK: - Pipeline Section

    private var pipelineSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EBPSpacing.lg) {

                // Horizontal pipeline stages
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: EBPSpacing.sm) {
                        ForEach(LeadStage.allCases) { stage in
                            pipelineColumn(stage: stage)
                        }
                    }
                    .padding(.horizontal, EBPSpacing.md)
                    .padding(.vertical, EBPSpacing.sm)
                }

                // Lost Reasons breakdown
                if let pipeline = vm.crmPipeline, !pipeline.lostReasons.isEmpty {
                    VStack(alignment: .leading, spacing: EBPSpacing.sm) {
                        EBPSectionHeader(title: "Lost Reasons")
                            .ebpHPadding()

                        VStack(spacing: 0) {
                            ForEach(pipeline.lostReasons.prefix(5)) { reason in
                                HStack {
                                    Image(systemName: "xmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(EBPColor.danger)
                                        .frame(width: 24)
                                    Text(reason.lostReason ?? "Unknown")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(reason._count.lostReason)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, EBPSpacing.md)
                                .padding(.vertical, 10)
                                Divider().padding(.leading, EBPSpacing.xl + EBPSpacing.sm)
                            }
                        }
                        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
                        .ebpShadowSubtle()
                        .ebpHPadding()
                    }
                }

                Spacer(minLength: EBPSpacing.xxxl)
            }
            .padding(.vertical, EBPSpacing.md)
        }
    }

    private func pipelineColumn(stage: LeadStage) -> some View {
        let leads = vm.crmPipeline?.leadsByStatus.filter { $0.status == stage.rawValue } ?? []
        let count = leads.first?._count.status ?? 0
        let value = leads.first?._sum.estimatedValue ?? 0

        return VStack(alignment: .leading, spacing: EBPSpacing.sm) {
            // Column Header
            HStack(spacing: EBPSpacing.xs) {
                Circle()
                    .fill(stage.color)
                    .frame(width: 8, height: 8)
                Text(stage.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stage.color.opacity(0.15))
                    .foregroundStyle(stage.color)
                    .clipShape(Capsule())
            }

            // Value
            if value > 0 {
                Text(value.currencyFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Placeholder cards
            if count == 0 {
                Text("Empty")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 140, height: 44)
                    .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: EBPRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: EBPRadius.sm)
                            .strokeBorder(Color(.separator).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            } else {
                ForEach(0..<min(count, 3), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: EBPRadius.sm)
                        .fill(EBPColor.surface)
                        .frame(width: 140, height: 56)
                        .overlay(
                            HStack(spacing: EBPSpacing.xs) {
                                Circle()
                                    .fill(stage.color.opacity(0.25))
                                    .frame(width: 28, height: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemFill))
                                        .frame(width: 70, height: 8)
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemFill))
                                        .frame(width: 50, height: 6)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, EBPSpacing.sm)
                        )
                        .ebpShadowSubtle()
                }
                if count > 3 {
                    Text("+\(count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(stage.color)
                        .padding(.horizontal, EBPSpacing.sm)
                }
            }
        }
        .padding(EBPSpacing.sm)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .frame(width: 156, alignment: .topLeading)
    }

    // MARK: - Top Clients Section

    private var topClientsSection: some View {
        ScrollView {
            VStack(spacing: EBPSpacing.sm) {
                if vm.ltvClients.isEmpty {
                    EBPEmptyState(
                        icon: "person.2.slash",
                        title: "No Client Data",
                        subtitle: "Complete jobs to see lifetime value analytics."
                    )
                    .padding(.top, EBPSpacing.xl)
                } else {
                    ForEach(Array(vm.ltvClients.prefix(10).enumerated()), id: \.element.id) { idx, client in
                        topClientRow(rank: idx + 1, client: client)
                    }
                }
            }
            .padding(EBPSpacing.md)
        }
    }

    private func topClientRow(rank: Int, client: LTVClient) -> some View {
        HStack(spacing: EBPSpacing.md) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rank <= 3 ? EBPColor.gold.opacity(0.15) : EBPColor.surface)
                    .frame(width: 36, height: 36)
                Text("\(rank)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(rank <= 3 ? EBPColor.gold : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name.isEmpty ? client.company : client.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(client.jobCount) jobs • avg \(client.avgJobValue.currencyFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(client.totalRevenue.currencyFormatted)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EBPColor.primary)
                Text("LTV")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(EBPSpacing.md)
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        ScrollView {
            VStack(spacing: EBPSpacing.md) {
                insightCard(
                    icon: "arrow.up.right.circle.fill",
                    tint: EBPColor.success,
                    title: "Win More Bids",
                    body: "Follow up on 'SITE_VISIT' leads within 24 hours — data shows win rates are 3× higher."
                )
                insightCard(
                    icon: "calendar.badge.exclamationmark",
                    tint: EBPColor.warning,
                    title: "Schedule Follow-Ups",
                    body: "Set follow-up dates on all open leads. Leads with scheduled follow-ups close 40% more often."
                )
                insightCard(
                    icon: "star.fill",
                    tint: EBPColor.gold,
                    title: "Reward Top Clients",
                    body: "Your top 20% of clients generate 80% of revenue. Consider a VIP referral programme."
                )
                insightCard(
                    icon: "megaphone.fill",
                    tint: Color.indigo,
                    title: "Track Lead Sources",
                    body: "Tag every lead with a source (Referral, Google, Door Hanger) to see what marketing is actually working."
                )
            }
            .padding(EBPSpacing.md)
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
        .background(EBPColor.surface, in: RoundedRectangle(cornerRadius: EBPRadius.md))
        .ebpShadowSubtle()
    }
}

// ─── Lead Stage ───────────────────────────────────────────────────────────────

private enum LeadStage: String, CaseIterable, Identifiable {
    case new        = "NEW"
    case contacted  = "CONTACTED"
    case siteVisit  = "SITE_VISIT"
    case bidSent    = "BID_SENT"
    case won        = "WON"
    case lost       = "LOST"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new:       return "New"
        case .contacted: return "Contacted"
        case .siteVisit: return "Site Visit"
        case .bidSent:   return "Bid Sent"
        case .won:       return "Won"
        case .lost:      return "Lost"
        }
    }

    var color: Color {
        switch self {
        case .new:       return .blue
        case .contacted: return Color.indigo
        case .siteVisit: return EBPColor.warning
        case .bidSent:   return EBPColor.primary
        case .won:       return EBPColor.success
        case .lost:      return EBPColor.danger
        }
    }
}


