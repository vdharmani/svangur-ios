import Foundation

/// Remote recent-search operations (equivalent to the network-facing
/// members of Android's `SearchRepository`). The local recent-search
/// cache is a Presentation/local-storage concern handled separately by
/// `SearchViewModel` via `UserDefaults` and is intentionally not part
/// of this protocol.
protocol SearchRepositoryProtocol: Sendable {
    func fetchRecentSearches(deviceId: String, kind: String) async throws(AppError) -> [String]
    func addRecentSearch(
        deviceId: String,
        query: String,
        kind: String,
        lat: Double?,
        lng: Double?
    ) async throws(AppError)
    func clearRecentSearches(deviceId: String, kind: String) async throws(AppError)
}

extension SearchRepositoryProtocol {
    func fetchRecentSearches(deviceId: String, kind: String = "offer") async throws(AppError) -> [String] {
        try await fetchRecentSearches(deviceId: deviceId, kind: kind)
    }

    func addRecentSearch(
        deviceId: String,
        query: String,
        kind: String = "offer",
        lat: Double? = nil,
        lng: Double? = nil
    ) async throws(AppError) {
        try await addRecentSearch(deviceId: deviceId, query: query, kind: kind, lat: lat, lng: lng)
    }

    func clearRecentSearches(deviceId: String, kind: String = "offer") async throws(AppError) {
        try await clearRecentSearches(deviceId: deviceId, kind: kind)
    }
}
