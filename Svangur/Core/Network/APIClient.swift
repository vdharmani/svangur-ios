import Foundation

protocol APIClientProtocol: Sendable {
    func execute<T: Decodable>(_ endpoint: any Endpoint) async throws(AppError) -> T
    /// For endpoints whose response isn't JSON (e.g. Legal's `text/html` pages).
    func executeRaw(_ endpoint: any Endpoint) async throws(AppError) -> Data
}

final class APIClient: APIClientProtocol, Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let retryPolicy: RetryPolicy
    private let keychain: KeychainManagerProtocol

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = {
            let d = JSONDecoder()
            // Every DTO in this codebase declares explicit `CodingKeys` mapped to the literal wire
            // key (snake_case or not). `.convertFromSnakeCase` only matches a key when no exact
            // match is found first — but Foundation's JSONDecoder tries the *converted* container
            // lookup in a way that misses an explicit snake_case CodingKeys raw value, causing
            // `keyNotFound` (verified empirically). Leave key decoding literal; DTOs already do the mapping.
            d.dateDecodingStrategy = .iso8601
            return d
        }(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        keychain: KeychainManagerProtocol = KeychainManager()
    ) {
        self.session = session
        self.decoder = decoder
        self.retryPolicy = retryPolicy
        self.keychain = keychain
    }

    func execute<T: Decodable>(_ endpoint: any Endpoint) async throws(AppError) -> T {
        let data = try await executeRequest(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw error.toAppError()
        }
    }

    func executeRaw(_ endpoint: any Endpoint) async throws(AppError) -> Data {
        try await executeRequest(endpoint)
    }

    // MARK: - Private

    private func executeRequest(_ endpoint: any Endpoint) async throws(AppError) -> Data {
        var request = endpoint.urlRequest
        if endpoint.requiresAuth,
           let tokenData = keychain.read(key: BearerTokenKeychainKey.value),
           let token = String(data: tokenData, encoding: .utf8) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        Self.logRequest(request)

        for attempt in 0..<retryPolicy.maxAttempts {
            guard !Task.isCancelled else { throw .unknown(message: "Task cancelled") }

            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.unknown(message: "Invalid response")
                }

                Self.logResponse(request, httpResponse, data)

                if RetryPolicy.retryableHTTPCodes.contains(httpResponse.statusCode),
                   endpoint.method.isIdempotent,
                   attempt < retryPolicy.maxAttempts - 1 {
                    let delay = retryAfterHeader(httpResponse) ?? retryPolicy.delay(for: attempt)
                    try await Task.sleep(for: delay)
                    continue
                }

                try mapHTTPStatus(httpResponse.statusCode)

                return data
            } catch let error as AppError {
                throw error
            } catch {
                if RetryPolicy.isRetryable(error),
                   endpoint.method.isIdempotent,
                   attempt < retryPolicy.maxAttempts - 1 {
                    let delay = retryPolicy.delay(for: attempt)
                    try? await Task.sleep(for: delay)
                    continue
                }
                throw error.toAppError()
            }
        }

        throw AppError.network(message: "Request failed after \(retryPolicy.maxAttempts) attempts")
    }

    // MARK: - Debug logging
    // Uses `print` (not `Logger`) specifically here: `os.Logger` at `.debug` level is routed
    // through the unified logging system, which Xcode's console doesn't reliably surface for
    // every scheme/Xcode-version combination — `print` always shows up. `#if DEBUG`-gated,
    // so none of this reaches Release builds.

    private static func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "?"
        print("➡️ [Svangur] \(method) \(url)")
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            print("   headers: \(headers)")
        }
        if let body = request.httpBody {
            print("   body: \(bodyDescription(body))")
        }
        #endif
    }

    private static func logResponse(_ request: URLRequest, _ response: HTTPURLResponse, _ data: Data) {
        #if DEBUG
        let url = request.url?.absoluteString ?? "?"
        print("⬅️ [Svangur] \(response.statusCode) \(url)")
        print("   response: \(bodyDescription(data))")
        #endif
    }

    #if DEBUG
    private static func bodyDescription(_ data: Data) -> String {
        guard !data.isEmpty else { return "<empty>" }
        // Pretty-print JSON bodies; fall back to raw text (e.g. Legal's HTML) or a byte count.
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: pretty, encoding: .utf8) {
            return string
        }
        if let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "<\(data.count) bytes, non-UTF8>"
    }
    #endif

    private func mapHTTPStatus(_ code: Int) throws(AppError) {
        switch code {
        case 200..<300:
            return
        case 401:
            throw .unauthorized()
        case 404:
            throw .notFound()
        case 400..<500:
            throw .server(code: code, message: "Client error")
        case 500..<600:
            throw .server(code: code, message: "Server error")
        default:
            throw .unknown(message: "Unexpected HTTP status: \(code)")
        }
    }

    private func retryAfterHeader(_ response: HTTPURLResponse) -> Duration? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Int(value) else { return nil }
        return .seconds(seconds)
    }
}

