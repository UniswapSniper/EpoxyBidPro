import Foundation
import Combine

// MARK: - Response Models

struct DashboardData: Decodable {
    var activeJobs: Int
    var openBids: Int
    var overdueInvoices: Int
    var monthRevenue: Double
    var recentActivity: [ActivityItem]
}

struct ActivityItem: Decodable, Identifiable {
    var id: String
    var entityType: String?
    var action: String?
    var description: String?
    var createdAt: Date?
}

struct RevenueData: Decodable {
    var totalRevenue: Double
    var byMethod: [String: Double]
    var byDay: [String: Double]
    var range: String
}

struct BidAnalyticsData: Decodable {
    var total: Int
    var sent: Int
    var signed: Int
    var declined: Int
    var winRate: Int
    var avgBidValue: Double
    var range: String
}

struct ProfitabilityJob: Decodable, Identifiable {
    var jobId: String
    var title: String
    var totalSqFt: Double?
    var revenue: Double
    var cost: Double
    var margin: Double
    var actualHours: Double
    var coatingSystem: String?
    var completedAt: Date?

    var id: String { jobId }
}

struct ProfitabilityData: Decodable {
    var jobs: [ProfitabilityJob]
    var range: String
}

struct CRMPipelineData: Decodable {
    var leadsByStatus: [LeadStatusGroup]
    var lostReasons: [LostReasonGroup]
    var topClients: [TopClient]
}

struct LeadStatusGroup: Decodable, Identifiable {
    var status: String
    var _count: CountWrap
    var _sum: SumWrap
    var id: String { status }

    struct CountWrap: Decodable { var status: Int }
    struct SumWrap: Decodable { var estimatedValue: Double? }
}

struct LostReasonGroup: Decodable, Identifiable {
    var lostReason: String?
    var _count: CountWrap
    var id: String { lostReason ?? "Unknown" }

    struct CountWrap: Decodable { var lostReason: Int }
}

struct TopClient: Decodable, Identifiable {
    var id: String
    var firstName: String
    var lastName: String
    var company: String
    var totalRevenue: Double
}

struct SeasonalData: Decodable {
    var byMonth: [String: Double]
    var seasonalAvg: [SeasonalAvg]
}

struct SeasonalAvg: Decodable, Identifiable {
    var month: Int
    var avgRevenue: Double
    var id: Int { month }
}

struct BidByTypeRow: Decodable, Identifiable {
    var coatingSystem: String
    var total: Int
    var sent: Int
    var signed: Int
    var winRate: Int
    var revenue: Double
    var avgSqFt: Int
    var id: String { coatingSystem }
}

struct BidByTypeData: Decodable {
    var breakdown: [BidByTypeRow]
    var range: String
}

struct LTVClient: Decodable, Identifiable {
    var id: String
    var name: String
    var company: String
    var clientType: String
    var totalRevenue: Double
    var jobCount: Int
    var avgJobValue: Double
    var memberSinceDays: Int
}

// MARK: - ViewModel

@MainActor
final class AnalyticsViewModel: ObservableObject {

    // Dashboard
    @Published var dashboardData: DashboardData?
    // Revenue
    @Published var revenueData: RevenueData?
    @Published var seasonalData: SeasonalData?
    @Published var selectedRevenueRange: String = "30d"
    // Bids / Sales
    @Published var bidAnalytics: BidAnalyticsData?
    @Published var bidsByType: BidByTypeData?
    @Published var selectedBidRange: String = "90d"
    // Jobs
    @Published var profitability: ProfitabilityData?
    @Published var selectedJobRange: String = "90d"
    // CRM
    @Published var crmPipeline: CRMPipelineData?
    @Published var ltvClients: [LTVClient] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var exportURL: URL?
    @Published var showingExportShare = false

    private let baseURL = "https://api.epoxybidpro.com"
    private var token: String { KeychainHelper.shared.token ?? "" }

    // MARK: Load All
    func loadAll() async {
        isLoading = true
        errorMessage = nil
        async let dash: () = loadDashboard()
        async let rev: () = loadRevenue()
        async let bids: () = loadBidAnalytics()
        async let prof: () = loadProfitability()
        async let crm: () = loadCRMPipeline()
        _ = await (dash, rev, bids, prof, crm)
        isLoading = false
    }

    // MARK: Dashboard
    func loadDashboard() async {
        do {
            dashboardData = try await get("/analytics/dashboard")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Revenue
    func loadRevenue() async {
        do {
            async let rev: RevenueData = get("/analytics/revenue?range=\(selectedRevenueRange)")
            async let seas: SeasonalData = get("/analytics/revenue/seasonal")
            revenueData = try await rev
            seasonalData = try await seas
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Bid Analytics
    func loadBidAnalytics() async {
        do {
            async let ba: BidAnalyticsData = get("/analytics/bids?range=\(selectedBidRange)")
            async let bt: BidByTypeData = get("/analytics/bids/by-type?range=\(selectedBidRange)")
            bidAnalytics = try await ba
            bidsByType = try await bt
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Profitability
    func loadProfitability() async {
        do {
            profitability = try await get("/analytics/jobs/profitability?range=\(selectedJobRange)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: CRM
    func loadCRMPipeline() async {
        do {
            async let pipe: CRMPipelineData = get("/analytics/crm/pipeline")
            async let ltv: [String: [LTVClient]] = get("/analytics/crm/lifetime-value")
            crmPipeline = try await pipe
            // server wraps in { clients: [...] }
            if let clients = (try? await ltv)?["clients"] {
                ltvClients = clients
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Export CSV
    func exportCSV(type: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let url = URL(string: "\(baseURL)/analytics/reports/export-csv?type=\(type)&range=\(selectedJobRange)") else { return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(type)-export.csv")
            try data.write(to: tmpURL)
            exportURL = tmpURL
            showingExportShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Export Weekly PDF
    func exportWeeklyPDF() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let url = URL(string: "\(baseURL)/analytics/reports/weekly-pdf") else { return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, _) = try await URLSession.shared.data(for: req)
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("weekly-summary.pdf")
            try data.write(to: tmpURL)
            exportURL = tmpURL
            showingExportShare = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Helpers
    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Server wraps payload in { success, data }
        struct Envelope<P: Decodable>: Decodable { let data: P }
        return try decoder.decode(Envelope<T>.self, from: data).data
    }
}

// MARK: - KeychainHelper stub (reuse from BidViewModel if present)
private enum KeychainHelper {
    static let shared = KeychainHelperInstance()
    final class KeychainHelperInstance {
        var token: String? { UserDefaults.standard.string(forKey: "auth_token") }
    }
}
