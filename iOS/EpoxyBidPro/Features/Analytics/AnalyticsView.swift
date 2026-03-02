import SwiftUI

// MARK: - Analytics View

struct AnalyticsView: View {

    @StateObject private var vm = AnalyticsViewModel()
    @State private var selectedSection: Section = .revenue

    enum Section: String, CaseIterable {
        case revenue
        case sales
        case jobs
        case crm

        var localizedTitle: String {
            switch self {
            case .revenue: return NSLocalizedString("revenue", comment: "")
            case .sales:   return NSLocalizedString("sales", comment: "")
            case .jobs:    return NSLocalizedString("jobs", comment: "")
            case .crm:     return NSLocalizedString("crm", comment: "")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Section Picker ──────────────────────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Section.allCases, id: \.self) { section in
                            Button(section.localizedTitle) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSection = section
                                }
                            }
                            .font(.subheadline.weight(selectedSection == section ? .bold : .regular))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                selectedSection == section
                                    ? EBPColor.primary.opacity(0.12)
                                    : Color.clear,
                                in: Capsule()
                            )
                            .foregroundStyle(selectedSection == section ? EBPColor.primary : .primary)
                        }
                    }
                    .padding(.horizontal, EBPSpacing.sm)
                    .padding(.vertical, EBPSpacing.xs)
                }
                .overlay(alignment: .bottom) {
                    Divider()
                }

                // ── Content ─────────────────────────────────────────────────
                ZStack {
                    if vm.isLoading && vm.dashboardData == nil {
                        ProgressView(NSLocalizedString("loading.analytics", comment: ""))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        switch selectedSection {
                        case .revenue:
                            RevenueChartView(
                                revenueData: vm.revenueData,
                                seasonalData: vm.seasonalData,
                                selectedRange: $vm.selectedRevenueRange
                            ) {
                                await vm.loadRevenue()
                            }

                        case .sales:
                            SalesAnalyticsView(
                                bidAnalytics: vm.bidAnalytics,
                                bidsByType: vm.bidsByType,
                                selectedRange: $vm.selectedBidRange
                            ) {
                                await vm.loadBidAnalytics()
                            }

                        case .jobs:
                            JobProfitabilityView(
                                profitability: vm.profitability,
                                selectedRange: $vm.selectedJobRange,
                                onRangeChange: { await vm.loadProfitability() },
                                onExportCSV: { await vm.exportCSV(type: "profitability") }
                            )

                        case .crm:
                            CRMAnalyticsView(
                                pipeline: vm.crmPipeline,
                                ltvClients: vm.ltvClients
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(NSLocalizedString("analytics.title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await vm.exportWeeklyPDF() }
                        } label: {
                            Label(NSLocalizedString("weekly.pdf", comment: ""), systemImage: "doc.richtext")
                        }
                        Button {
                            Task { await vm.exportCSV(type: "revenue") }
                        } label: {
                            Label(NSLocalizedString("revenue.csv", comment: ""), systemImage: "tablecells")
                        }
                        Button {
                            Task { await vm.exportCSV(type: "profitability") }
                        } label: {
                            Label(NSLocalizedString("job.profit.csv", comment: ""), systemImage: "tablecells.badge.ellipsis")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
                        Task { await vm.loadAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert(NSLocalizedString("error", comment: ""), isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button(NSLocalizedString("ok", comment: "")) { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? NSLocalizedString("unknown.error", comment: ""))
            }
            .sheet(isPresented: $vm.showingExportShare) {
                if let url = vm.exportURL {
                    ShareSheet(items: [url])
                        .onDisappear { vm.showingExportShare = false }
                }
            }
        }
        .task { await vm.loadAll() }
    }
}

// MARK: - ShareSheet Bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    AnalyticsView()
}
