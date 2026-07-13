import Foundation

/// Search-results network operations (equivalent to Android's
/// `SearchResultsRepository`).
protocol SearchResultsRepositoryProtocol: Sendable {
    func search(query: String, lat: Double?, lng: Double?) async throws(AppError) -> [SearchOffer]
    func searchByLocation(query: String, lat: Double, lng: Double) async throws(AppError) -> [SearchOffer]
}

extension SearchResultsRepositoryProtocol {
    func search(query: String, lat: Double? = nil, lng: Double? = nil) async throws(AppError) -> [SearchOffer] {
        try await search(query: query, lat: lat, lng: lng)
    }
}
