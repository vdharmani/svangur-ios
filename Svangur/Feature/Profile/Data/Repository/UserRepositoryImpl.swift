import Foundation

final class UserRepositoryImpl: UserRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getUser(id: String) async throws(AppError) -> User {
        return try await apiCall {
            let dto: UserDTO = try await apiClient.execute(UserEndpoint.getUser(id: id))
            return dto.toDomain()
        }
    }
}

// MARK: - Mock for Tracer Bullet (no real backend yet)

final class MockUserRepository: UserRepositoryProtocol, Sendable {
    func getUser(id: String) async throws(AppError) -> User {
        try? await Task.sleep(for: .seconds(1))
        return User(
            id: id,
            name: "Gurdeep Singh",
            email: "gurdeep@svangur.is",
            avatarUrl: nil,
            memberSince: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
