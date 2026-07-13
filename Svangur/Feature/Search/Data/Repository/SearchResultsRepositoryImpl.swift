import Foundation

final class SearchResultsRepositoryImpl: SearchResultsRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func search(query: String, lat: Double?, lng: Double?) async throws(AppError) -> [SearchOffer] {
        try await apiCall {
            let envelope: SearchResponseEnvelopeDTO = try await apiClient.execute(
                SearchEndpoint.search(query: query, lat: lat, lng: lng)
            )
            return envelope.data.items.map { $0.toDomain() }
        }
    }

    func searchByLocation(query: String, lat: Double, lng: Double) async throws(AppError) -> [SearchOffer] {
        try await apiCall {
            let envelope: SearchResponseEnvelopeDTO = try await apiClient.execute(
                SearchEndpoint.searchByLocation(query: query, lat: lat, lng: lng)
            )
            return envelope.data.items.map { $0.toDomain() }
        }
    }
}
