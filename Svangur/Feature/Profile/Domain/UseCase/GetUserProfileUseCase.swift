protocol GetUserProfileUseCaseProtocol: Sendable {
    func execute(id: String) async throws(AppError) -> User
}

final class GetUserProfileUseCase: GetUserProfileUseCaseProtocol, Sendable {
    private let userRepository: UserRepositoryProtocol

    init(userRepository: UserRepositoryProtocol) {
        self.userRepository = userRepository
    }

    func execute(id: String) async throws(AppError) -> User {
        guard !id.isEmpty else {
            throw .validation(message: "User ID must not be empty")
        }
        return try await userRepository.getUser(id: id)
    }
}
