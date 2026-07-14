protocol LoginUseCaseProtocol: Sendable {
    func execute(credentials: Credentials) async throws(AppError) -> AuthToken
}

final class LoginUseCase: LoginUseCaseProtocol, Sendable {
    private let authRepository: AuthRepositoryProtocol
    private let validate: ValidateCredentialsUseCaseProtocol

    init(
        authRepository: AuthRepositoryProtocol,
        validate: ValidateCredentialsUseCaseProtocol
    ) {
        self.authRepository = authRepository
        self.validate = validate
    }

    func execute(credentials: Credentials) async throws(AppError) -> AuthToken {
        let result = validate.validateLogin(email: credentials.email, password: credentials.password)
        guard result.isValid else {
            throw .validation(message: "Please check your email and password.")
        }
        return try await authRepository.login(credentials: credentials)
    }
}
