import Foundation

// ═══════════════════════════════════════════════════════════════════════════════
// APIClient.swift
// Actor-based networking layer with automatic token refresh, retry, and
// offline detection. All backend calls flow through this single client.
// ═══════════════════════════════════════════════════════════════════════════════

actor APIClient {

    // MARK: - Singleton

    static let shared = APIClient()

    // MARK: - Configuration

    private var baseURL: URL {
        let urlString = UserDefaults.standard.string(forKey: "assistantAPIBaseURL")
            ?? ProcessInfo.processInfo.environment["API_BASE_URL"]
            ?? "https://api.epoxybidpro.com/v1"
        return URL(string: urlString)!
    }

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case invalidURL
        case unauthorized
        case forbidden
        case notFound
        case serverError(Int, String?)
        case networkError(Error)
        case decodingError(Error)
        case noData
        case offline

        var errorDescription: String? {
            switch self {
            case .invalidURL:             return "Invalid URL"
            case .unauthorized:           return "Session expired — please sign in again"
            case .forbidden:              return "Access denied"
            case .notFound:               return "Resource not found"
            case .serverError(let c, _):  return "Server error (\(c))"
            case .networkError(let e):    return e.localizedDescription
            case .decodingError:          return "Failed to parse response"
            case .noData:                 return "No data received"
            case .offline:                return "You're offline — changes will sync when connected"
            }
        }
    }

    // MARK: - Standard API Response Wrapper

    struct APIResponse<T: Decodable>: Decodable {
        let success: Bool
        let data: T?
        let error: String?
    }

    // MARK: - Primary Request Method

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        // Build URL
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = endpoint.queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Inject auth token
        if let token = KeychainService.loadString(key: .accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Encode body
        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        // Execute
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        // Handle HTTP status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            // Attempt token refresh once
            if let refreshed = try? await refreshAndRetry(endpoint, as: T.self) {
                return refreshed
            }
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.serverError(httpResponse.statusCode, message)
        }

        // Decode
        do {
            let wrapped = try decoder.decode(APIResponse<T>.self, from: data)
            if let result = wrapped.data {
                return result
            }
            // Try decoding directly if not wrapped
            return try decoder.decode(T.self, from: data)
        } catch {
            // Fallback: try direct decode
            do {
                return try decoder.decode(T.self, from: data)
            } catch let decodingError {
                throw APIError.decodingError(decodingError)
            }
        }
    }

    // MARK: - Fire & Forget (no response body needed)

    func send(_ endpoint: APIEndpoint) async throws {
        let _: EmptyResponse = try await request(endpoint)
    }

    // MARK: - Token Refresh

    private var isRefreshing = false

    private func refreshAndRetry<T: Decodable>(_ endpoint: APIEndpoint, as type: T.Type) async throws -> T? {
        guard !isRefreshing else { return nil }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = KeychainService.loadString(key: .refreshToken) else {
            return nil
        }

        let refreshEndpoint = APIEndpoint.refreshToken(refreshToken)

        var components = URLComponents(url: baseURL.appendingPathComponent(refreshEndpoint.path), resolvingAgainstBaseURL: false)
        components?.queryItems = refreshEndpoint.queryItems

        guard let url = components?.url else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = refreshEndpoint.body {
            req.httpBody = try? encoder.encode(AnyEncodable(body))
        }

        guard let (data, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else {
            return nil
        }

        struct TokenPair: Decodable { let accessToken: String; let refreshToken: String }

        if let wrapped = try? decoder.decode(APIResponse<TokenPair>.self, from: data),
           let tokens = wrapped.data {
            KeychainService.save(key: .accessToken, string: tokens.accessToken)
            KeychainService.save(key: .refreshToken, string: tokens.refreshToken)

            // Retry original request with new token
            return try await request(endpoint)
        }

        return nil
    }
}

// MARK: - Helper Types

private struct EmptyResponse: Decodable {}

/// Type-erased Encodable wrapper for heterogeneous body types.
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
