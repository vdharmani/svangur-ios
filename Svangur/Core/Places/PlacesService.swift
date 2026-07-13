import Foundation
import GooglePlacesSwift

protocol PlacesServiceProtocol: Sendable {
    /// Address autocomplete suggestions for the given (partial) query text — scoped to one
    /// internal Places session until `resetSession()` is called, so Google bills a whole
    /// search as a single session rather than per-keystroke.
    func autocomplete(query: String) async throws(AppError) -> [PlaceSuggestion]
    /// Starts a fresh billing session — call after a suggestion is selected or a search is
    /// abandoned, so the next search isn't billed as a continuation of this one.
    func resetSession() async
}

actor PlacesService: PlacesServiceProtocol {
    private var sessionToken = AutocompleteSessionToken()

    func autocomplete(query: String) async throws(AppError) -> [PlaceSuggestion] {
        let request = AutocompleteRequest(query: query, sessionToken: sessionToken)
        let result = await PlacesClient.shared.fetchAutocompleteSuggestions(with: request)
        switch result {
        case .success(let suggestions):
            return suggestions.compactMap { suggestion in
                guard case .place(let place) = suggestion else { return nil }
                // `place.description` is Swift's synthesized debug description of the whole
                // object, not display text — the actual "Mohali, Punjab, India" string lives on
                // `legacyAttributedFullText` (NSAttributedString), so unwrap its plain `.string`.
                return PlaceSuggestion(id: place.placeID, description: place.legacyAttributedFullText.string)
            }
        case .failure(let error):
            throw error.toAppError()
        }
    }

    func resetSession() {
        sessionToken = AutocompleteSessionToken()
    }
}

private extension PlacesError {
    func toAppError() -> AppError {
        switch self {
        case .network(let message):
            return .network(message: message)
        case .rateLimitExceeded(let message), .deviceRateLimitExceeded(let message), .usageLimitExceeded(let message):
            return .server(code: 429, message: message)
        case .invalidRequest(let message):
            return .validation(message: message)
        default:
            return .unknown(message: "\(self)")
        }
    }
}
