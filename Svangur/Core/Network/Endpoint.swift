import Foundation

protocol Endpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    /// Whether `APIClient` should attach `Authorization: Bearer <token>`. Defaults to `true` —
    /// public endpoints (login, register, Deals/Search/Days/Legal/Bootstrap browsing) opt out
    /// explicitly since they either have no token yet or don't need one.
    var requiresAuth: Bool { get }
}

extension Endpoint {
    var headers: [String: String] {
        ["Content-Type": "application/json", "Accept": "application/json"]
    }

    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var requiresAuth: Bool { true }

    var urlRequest: URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        var request = URLRequest(url: components?.url ?? baseURL.appendingPathComponent(path))
        request.httpMethod = method.rawValue
        request.httpBody = body

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if case .post(let idempotencyKey) = method, let key = idempotencyKey {
            request.setValue(key.uuidString, forHTTPHeaderField: "Idempotency-Key")
        }

        return request
    }
}
