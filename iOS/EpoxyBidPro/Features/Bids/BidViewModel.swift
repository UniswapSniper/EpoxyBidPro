import Foundation
import SwiftData
import Combine

// ─── BidViewModel ─────────────────────────────────────────────────────────────
// Drives BidsView, BidDetailView, and the proposal send/sign flow.

@MainActor
final class BidViewModel: ObservableObject {

    // MARK: - Published State

    @Published var bids: [Bid] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var isSending = false
    @Published var isGeneratingPdf = false
    @Published var pdfUrl: URL? = nil
    @Published var selectedFilter: BidStatusFilter = .all
    @Published var searchText = ""

    // MARK: - Filtering

    enum BidStatusFilter: String, CaseIterable, Identifiable {
        case all      = "All"
        case draft    = "Draft"
        case sent     = "Sent"
        case viewed   = "Viewed"
        case signed   = "Signed"
        case declined = "Declined"
        case expired  = "Expired"

        var id: String { rawValue }

        var apiStatus: String? {
            switch self {
            case .all:      return nil
            case .draft:    return "DRAFT"
            case .sent:     return "SENT"
            case .viewed:   return "VIEWED"
            case .signed:   return "SIGNED"
            case .declined: return "DECLINED"
            case .expired:  return "EXPIRED"
            }
        }
    }

    var filteredBids: [Bid] {
        var result = bids

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

    // MARK: - Init

    init() {}

    // MARK: - Load Bids (SwiftData — offline-first)

    func loadBids(from context: ModelContext) {
        let descriptor = FetchDescriptor<Bid>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            bids = try context.fetch(descriptor)
        } catch {
            errorMessage = "Could not load bids: \(error.localizedDescription)"
        }
    }

    // MARK: - Create New Bid (local draft)

    func createDraftBid(
        client: Client? = nil,
        measurement: Measurement? = nil,
        context: ModelContext
    ) -> Bid {
        let bid = Bid()
        bid.bidNumber = "BID-\(Int.random(in: 1001...9999))"   // temp — overwritten on sync
        bid.title = client != nil ? "\(client!.displayName) — Epoxy Floor" : "New Bid"
        bid.status = "DRAFT"
        bid.client = client
        bid.measurement = measurement
        bid.totalSqFt = measurement?.totalSqFt ?? 0

        context.insert(bid)
        try? context.save()
        loadBids(from: context)
        return bid
    }

    // MARK: - Delete Bid

    func deleteBid(_ bid: Bid, context: ModelContext) {
        context.delete(bid)
        try? context.save()
        loadBids(from: context)
    }

    // MARK: - Send Bid (PDF + email via backend)

    func sendBid(_ bid: Bid, deliveryMethod: String = "email", customMessage: String? = nil) async {
        guard let bidId = bid.backendId.isEmpty ? nil : bid.backendId else {
            errorMessage = "Bid must be synced to backend before sending."
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            var request = try APIClient.request(
                path: "/bids/\(bidId)/send",
                method: "POST"
            )
            let body: [String: Any] = [
                "deliveryMethod": deliveryMethod,
                "customMessage": customMessage as Any,
            ].compactMapValues { $0 }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
            }

            if let json = try? JSONDecoder().decode(APIResponse<SendBidResult>.self, from: data) {
                bid.status = "SENT"
                bid.pdfUrl = json.data.pdfUrl ?? ""
                bid.sentAt = Date()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Generate PDF (preview)

    func generatePdf(for bid: Bid) async {
        guard let bidId = bid.backendId.isEmpty ? nil : bid.backendId else {
            errorMessage = "Bid must be synced to backend first."
            return
        }

        isGeneratingPdf = true
        defer { isGeneratingPdf = false }

        do {
            let request = try APIClient.request(path: "/bids/\(bidId)/pdf", method: "GET")
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONDecoder().decode(APIResponse<PdfResult>.self, from: data),
               let urlString = json.data.pdfUrl,
               let url = URL(string: urlString) {
                pdfUrl = url
                bid.pdfUrl = urlString
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mark Declined

    func declineBid(_ bid: Bid, reason: String? = nil, context: ModelContext) async {
        guard let bidId = bid.backendId.isEmpty ? nil : bid.backendId else {
            bid.status = "DECLINED"
            bid.declinedAt = Date()
            try? context.save()
            return
        }

        do {
            var request = try APIClient.request(path: "/bids/\(bidId)/decline", method: "POST")
            let body: [String: Any] = reason.map { ["reason": $0] } ?? [:]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let _ = try await URLSession.shared.data(for: request)
        } catch {
            errorMessage = error.localizedDescription
        }

        bid.status = "DECLINED"
        bid.declinedAt = Date()
        try? context.save()
        loadBids(from: context)
    }

    // MARK: - Convert to Job

    func convertToJob(_ bid: Bid, context: ModelContext) async {
        guard let bidId = bid.backendId.isEmpty ? nil : bid.backendId else {
            errorMessage = "Bid must be synced first."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let request = try APIClient.request(
                path: "/bids/\(bidId)/convert-to-job",
                method: "POST"
            )
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Clone Bid

    func cloneBid(_ bid: Bid, context: ModelContext) async {
        guard let bidId = bid.backendId.isEmpty ? nil : bid.backendId else {
            errorMessage = "Bid must be synced first."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let request = try APIClient.request(
                path: "/bids/\(bidId)/clone",
                method: "POST"
            )
            let _ = try await URLSession.shared.data(for: request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Submit Signature

    func submitSignature(
        bid: Bid,
        signerName: String,
        signerEmail: String?,
        dataUrl: String,
        context: ModelContext
    ) async {
        guard let bidId = bid.backendId.isEmpty ? nil : bid.backendId else {
            // Offline: record signature locally
            let sig = BidSignature()
            sig.signerName = signerName
            sig.signatureDataBase64 = dataUrl
            sig.signedAt = Date()
            bid.signature = sig
            bid.status = "SIGNED"
            bid.signedAt = Date()
            try? context.save()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var request = try APIClient.request(path: "/bids/\(bidId)/sign", method: "POST")
            var body: [String: Any] = ["signerName": signerName, "dataUrl": dataUrl]
            if let email = signerEmail { body["signerEmail"] = email }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
            }

            bid.status = "SIGNED"
            bid.signedAt = Date()
            let sig = BidSignature()
            sig.signerName = signerName
            sig.signatureDataBase64 = dataUrl
            sig.signedAt = Date()
            bid.signature = sig
            try? context.save()
            loadBids(from: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ─── Supporting Types ─────────────────────────────────────────────────────────

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T
}

struct SendBidResult: Decodable {
    let sent: Bool
    let pdfUrl: String?
    let bidNumber: String?
}

struct PdfResult: Decodable {
    let pdfUrl: String?
    let bidNumber: String?
}

enum APIError: LocalizedError {
    case httpError(Int)
    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "Server error (\(code))"
        }
    }
}

// ─── Minimal API Client ───────────────────────────────────────────────────────

enum APIClient {
    static var baseURL: String {
        ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://api.epoxybidpro.com/v1"
    }

    static func request(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = KeychainHelper.readToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}

// ─── Keychain Helper (stub — full implementation in Auth phase) ───────────────

enum KeychainHelper {
    static func readToken() -> String? {
        UserDefaults.standard.string(forKey: "ebp_access_token")
    }
}
