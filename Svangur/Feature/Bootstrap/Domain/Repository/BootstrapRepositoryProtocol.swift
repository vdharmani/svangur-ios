import Foundation

protocol BootstrapRepositoryProtocol: Sendable {
    func getBootstrap(lang: String, tz: String, featuredLimit: Int) async throws(AppError) -> BootstrapData
}
