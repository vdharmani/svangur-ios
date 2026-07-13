import Foundation

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let baseDelay: Duration
    let maxDelay: Duration
    let jitterRange: ClosedRange<Double>

    init(
        maxAttempts: Int = 3,
        baseDelay: Duration = .milliseconds(500),
        maxDelay: Duration = .seconds(8),
        jitterRange: ClosedRange<Double> = 0.8...1.2
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterRange = jitterRange
    }

    func delay(for attempt: Int) -> Duration {
        let base = Double(baseDelay.components.seconds) + Double(baseDelay.components.attoseconds) * 1e-18
        let exponential = base * pow(2.0, Double(attempt))
        let maxSeconds = Double(maxDelay.components.seconds) + Double(maxDelay.components.attoseconds) * 1e-18
        let capped = min(exponential, maxSeconds)
        let jittered = capped * Double.random(in: jitterRange)
        return .milliseconds(Int(jittered * 1000))
    }

    static let retryableHTTPCodes: Set<Int> = [408, 429, 502, 503, 504]

    static func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.notConnectedToInternet, .timedOut, .networkConnectionLost].contains(urlError.code)
        }
        return false
    }
}
