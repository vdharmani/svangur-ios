import Foundation

protocol LegalRepositoryProtocol: Sendable {
    func getTerms(lang: String) async throws(AppError) -> String
    func getPrivacy(lang: String) async throws(AppError) -> String
}
