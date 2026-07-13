protocol LogoutUseCaseProtocol: Sendable {
    func execute() async throws(AppError)
}

final class LogoutUseCase: LogoutUseCaseProtocol, Sendable {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute() async throws(AppError) {
        try await authRepository.logout()
    }
}
