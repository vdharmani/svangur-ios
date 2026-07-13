import Foundation

final class SearchRepositoryImpl: SearchRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func fetchRecentSearches(deviceId: String, kind: String) async throws(AppError) -> [String] {
        try await apiCall {
            let envelope: RecentSearchEnvelopeDTO = try await apiClient.execute(
                SearchEndpoint.getRecentSearches(deviceId: deviceId, kind: kind)
            )
            return envelope.data.items.map(\.query)
        }
    }

    func addRecentSearch(
        deviceId: String,
        query: String,
        kind: String,
        lat: Double?,
        lng: Double?
    ) async throws(AppError) {
        try await apiCall {
            let body = AddRecentSearchRequestDTO(
                deviceId: deviceId,
                query: query,
                kind: kind,
                latitude: lat,
                longitude: lng
            )
            let _: EmptyResponse = try await apiClient.execute(SearchEndpoint.addRecentSearch(body: body))
        }
    }

    func clearRecentSearches(deviceId: String, kind: String) async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(
                SearchEndpoint.clearRecentSearches(deviceId: deviceId, kind: kind)
            )
        }
    }
}

private struct EmptyResponse: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}
