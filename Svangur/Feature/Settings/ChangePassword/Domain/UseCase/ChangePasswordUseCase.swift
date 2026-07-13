protocol ChangePasswordUseCaseProtocol: Sendable {
    func execute(currentPassword: String, newPassword: String, confirmPassword: String) async throws(AppError)
}

final class ChangePasswordUseCase: ChangePasswordUseCaseProtocol, Sendable {
    private let changePasswordRepository: ChangePasswordRepositoryProtocol

    init(changePasswordRepository: ChangePasswordRepositoryProtocol) {
        self.changePasswordRepository = changePasswordRepository
    }

    func execute(currentPassword: String, newPassword: String, confirmPassword: String) async throws(AppError) {
        try await changePasswordRepository.changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
            confirmPassword: confirmPassword
        )
    }
}
