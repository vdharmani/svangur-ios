import Foundation

final class BootstrapRepositoryImpl: BootstrapRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getBootstrap(lang: String, tz: String, featuredLimit: Int) async throws(AppError) -> BootstrapData {
        try await apiCall {
            let response: BootstrapResponseDTO = try await apiClient.execute(
                BootstrapEndpoint.getBootstrap(lang: lang, tz: tz, featuredLimit: featuredLimit)
            )
            return response.data.toDomain()
        }
    }
}
