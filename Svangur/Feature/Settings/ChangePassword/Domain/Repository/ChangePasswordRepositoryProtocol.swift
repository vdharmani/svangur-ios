import Foundation

protocol ChangePasswordRepositoryProtocol: Sendable {
    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async throws(AppError)
}
