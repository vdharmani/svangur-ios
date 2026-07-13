import Foundation

final class DeleteAccountRepositoryImpl: DeleteAccountRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func deleteAccount() async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(DeleteAccountEndpoint.deleteAccount)
        }
    }
}

private struct EmptyResponse: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}
