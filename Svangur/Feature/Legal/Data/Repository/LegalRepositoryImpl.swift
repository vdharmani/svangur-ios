import Foundation

final class LegalRepositoryImpl: LegalRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getTerms(lang: String) async throws(AppError) -> String {
        try await apiCall {
            let data = try await apiClient.executeRaw(LegalEndpoint.terms(lang: lang))
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    func getPrivacy(lang: String) async throws(AppError) -> String {
        try await apiCall {
            let data = try await apiClient.executeRaw(LegalEndpoint.privacy(lang: lang))
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}
