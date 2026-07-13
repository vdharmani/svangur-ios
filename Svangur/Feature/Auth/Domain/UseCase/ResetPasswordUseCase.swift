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
            throw .validation(message: "auth.error.invalid_reset_token")
        }
        let result = validate.validateNewPassword(newPassword, confirm: confirm)
        guard result.isValid else {
            throw .validation(message: "auth.error.invalid_new_password")
        }
        try await authRepository.resetPassword(
            PasswordResetToken(token: token, newPassword: newPassword)
        )
    }
}
