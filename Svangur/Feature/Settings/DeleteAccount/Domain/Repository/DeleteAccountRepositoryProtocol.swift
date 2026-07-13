import Foundation

protocol DeleteAccountRepositoryProtocol: Sendable {
    func deleteAccount() async throws(AppError)
}
