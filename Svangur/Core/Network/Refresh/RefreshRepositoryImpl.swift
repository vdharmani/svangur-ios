import Foundation

final class RefreshRepositoryImpl: RefreshRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func refresh() async throws(AppError) -> String {
        try await apiCall {
            let response: RefreshResponseDTO = try await apiClient.execute(RefreshEndpoint.refresh)
            return response.data.token
        }
    }
}
