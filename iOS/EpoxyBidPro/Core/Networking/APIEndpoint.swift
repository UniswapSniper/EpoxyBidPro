import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// APIEndpoint.swift
// Typed API endpoint definitions — every backend call is defined here.
// ═══════════════════════════════════════════════════════════════════════════════

enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case patch  = "PATCH"
    case delete = "DELETE"
}

struct APIEndpoint {
    let method: HTTPMethod
    let path: String
    let body: Encodable?
    let queryItems: [URLQueryItem]?

    init(method: HTTPMethod, path: String, body: Encodable? = nil, queryItems: [URLQueryItem]? = nil) {
        self.method = method
        self.path = path
        self.body = body
        self.queryItems = queryItems
    }
}

// MARK: - Auth Endpoints

extension APIEndpoint {

    static func register(email: String, password: String, firstName: String, lastName: String, businessName: String) -> APIEndpoint {
        struct Body: Encodable { let email, password, firstName, lastName, businessName: String }
        return APIEndpoint(method: .post, path: "/auth/register", body: Body(email: email, password: password, firstName: firstName, lastName: lastName, businessName: businessName))
    }

    static func login(email: String, password: String) -> APIEndpoint {
        struct Body: Encodable { let email, password: String }
        return APIEndpoint(method: .post, path: "/auth/login", body: Body(email: email, password: password))
    }

    static func appleSignIn(identityToken: String, firstName: String?, lastName: String?) -> APIEndpoint {
        struct Body: Encodable { let identityToken: String; let firstName: String?; let lastName: String? }
        return APIEndpoint(method: .post, path: "/auth/apple", body: Body(identityToken: identityToken, firstName: firstName, lastName: lastName))
    }

    static func refreshToken(_ refreshToken: String) -> APIEndpoint {
        struct Body: Encodable { let refreshToken: String }
        return APIEndpoint(method: .post, path: "/auth/refresh", body: Body(refreshToken: refreshToken))
    }

    static var me: APIEndpoint {
        APIEndpoint(method: .get, path: "/auth/me")
    }
}

// MARK: - Client Endpoints

extension APIEndpoint {

    static func listClients(page: Int = 1, limit: Int = 50, search: String? = nil) -> APIEndpoint {
        var items = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "limit", value: "\(limit)")]
        if let search { items.append(URLQueryItem(name: "search", value: search)) }
        return APIEndpoint(method: .get, path: "/clients", queryItems: items)
    }

    static func getClient(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/clients/\(id)")
    }

    static func createClient(_ body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/clients", body: body)
    }

    static func updateClient(id: String, body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .put, path: "/clients/\(id)", body: body)
    }

    static func deleteClient(id: String) -> APIEndpoint {
        APIEndpoint(method: .delete, path: "/clients/\(id)")
    }
}

// MARK: - Lead Endpoints

extension APIEndpoint {

    static func listLeads(status: String? = nil, page: Int = 1) -> APIEndpoint {
        var items = [URLQueryItem(name: "page", value: "\(page)")]
        if let status { items.append(URLQueryItem(name: "status", value: status)) }
        return APIEndpoint(method: .get, path: "/leads", queryItems: items)
    }

    static func createLead(_ body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/leads", body: body)
    }

    static func updateLead(id: String, body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .put, path: "/leads/\(id)", body: body)
    }
}

// MARK: - Bid Endpoints

extension APIEndpoint {

    static func listBids(status: String? = nil, page: Int = 1) -> APIEndpoint {
        var items = [URLQueryItem(name: "page", value: "\(page)")]
        if let status { items.append(URLQueryItem(name: "status", value: status)) }
        return APIEndpoint(method: .get, path: "/bids", queryItems: items)
    }

    static func getBid(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/bids/\(id)")
    }

    static func generateBid(_ body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/bids/generate", body: body)
    }

    static func sendBid(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/bids/\(id)/send")
    }

    static func signBid(id: String, body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/bids/\(id)/sign", body: body)
    }

    static func bidPDF(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/bids/\(id)/pdf")
    }

    static func bidAISuggest(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/bids/\(id)/ai-suggest")
    }

    static func convertBidToJob(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/bids/\(id)/convert-to-job")
    }

    static func cloneBid(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/bids/\(id)/clone")
    }

    static func pricingPreview(_ body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/bids/pricing/preview", body: body)
    }
}

// MARK: - Job Endpoints

extension APIEndpoint {

    static func listJobs(status: String? = nil, page: Int = 1) -> APIEndpoint {
        var items = [URLQueryItem(name: "page", value: "\(page)")]
        if let status { items.append(URLQueryItem(name: "status", value: status)) }
        return APIEndpoint(method: .get, path: "/jobs", queryItems: items)
    }

    static func getJob(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/jobs/\(id)")
    }

    static func createJob(_ body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/jobs", body: body)
    }

    static func updateJobStatus(id: String, status: String) -> APIEndpoint {
        struct Body: Encodable { let status: String }
        return APIEndpoint(method: .patch, path: "/jobs/\(id)/status", body: Body(status: status))
    }
}

// MARK: - Invoice Endpoints

extension APIEndpoint {

    static func listInvoices(status: String? = nil, page: Int = 1) -> APIEndpoint {
        var items = [URLQueryItem(name: "page", value: "\(page)")]
        if let status { items.append(URLQueryItem(name: "status", value: status)) }
        return APIEndpoint(method: .get, path: "/invoices", queryItems: items)
    }

    static func createInvoiceFromJob(jobId: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/invoices/from-job/\(jobId)")
    }

    static func sendInvoice(id: String) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/invoices/\(id)/send")
    }

    static func recordPayment(_ body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/payments/record-payment", body: body)
    }
}

// MARK: - Measurement Endpoints

extension APIEndpoint {

    static func createMeasurement(_ body: Encodable) -> APIEndpoint {
        APIEndpoint(method: .post, path: "/measurements", body: body)
    }

    static func getMeasurement(id: String) -> APIEndpoint {
        APIEndpoint(method: .get, path: "/measurements/\(id)")
    }
}

// MARK: - Analytics Endpoints

extension APIEndpoint {

    static var dashboard: APIEndpoint {
        APIEndpoint(method: .get, path: "/analytics/dashboard")
    }

    static func revenue(range: String = "30d") -> APIEndpoint {
        APIEndpoint(method: .get, path: "/analytics/revenue", queryItems: [URLQueryItem(name: "range", value: range)])
    }
}

// MARK: - Assistant Endpoint

extension APIEndpoint {

    static func assistantChat(message: String, mode: String = "chat", tone: String = "friendly") -> APIEndpoint {
        struct Body: Encodable { let message, mode, tone: String }
        return APIEndpoint(method: .post, path: "/assistant/chat", body: Body(message: message, mode: mode, tone: tone))
    }
}
