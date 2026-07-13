import Foundation

protocol RefreshRepositoryProtocol: Sendable {
    func refresh() async throws(AppError) -> String
}
