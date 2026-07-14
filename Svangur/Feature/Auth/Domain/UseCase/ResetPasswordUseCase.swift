protocol ResetPasswordUseCaseProtocol: Sendable {
    func execute(token: String, newPassword: String, confirm: String) async throws(AppError)
}

final class ResetPasswordUseCase: ResetPasswordUseCaseProtocol, Sendable {
    private let authRepository: AuthRepositoryProtocol
    private let validate: ValidateCredentialsUseCaseProtocol

    init(
        authRepository: AuthRepositoryProtocol,
        validate: ValidateCredentialsUseCaseProtocol
    ) {
        self.authRepository = authRepository
        self.validate = validate
    }

    func execute(token: String, newPassword: String, confirm: String) async throws(AppError) {
        guard !token.isEmpty else {
            throw .validation(message: "This reset link is invalid or has expired.")
        }
        let result = validate.validateNewPassword(newPassword, confirm: confirm)
        guard result.isValid else {
            throw .validation(message: "Please choose a valid password.")
        }
        try await authRepository.resetPassword(
            PasswordResetToken(token: token, newPassword: newPassword)
        )
    }
}
