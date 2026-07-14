protocol RequestPasswordResetUseCaseProtocol: Sendable {
    func execute(email: String) async throws(AppError)
}

final class RequestPasswordResetUseCase: RequestPasswordResetUseCaseProtocol, Sendable {
    private let authRepository: AuthRepositoryProtocol
    private let validate: ValidateCredentialsUseCaseProtocol

    init(
        authRepository: AuthRepositoryProtocol,
        validate: ValidateCredentialsUseCaseProtocol
    ) {
        self.authRepository = authRepository
        self.validate = validate
    }

    func execute(email: String) async throws(AppError) {
        if let error = validate.validateEmailFormat(email) {
            throw .validation(
                message: error == .empty
                    ? "Please enter your email address."
                    : "Please enter a valid email address."
            )
        }
        try await authRepository.requestPasswordReset(email: email)
    }
}
