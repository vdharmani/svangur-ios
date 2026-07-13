import Foundation

final class ChangePasswordRepositoryImpl: ChangePasswordRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(
                ChangePasswordEndpoint.changePassword(
                    body: ChangePasswordRequestDTO(
                        oldPassword: currentPassword,
                        newPassword: newPassword,
                        confirmPassword: confirmPassword
                    )
                )
            )
        }
    }
}

private struct EmptyResponse: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}
