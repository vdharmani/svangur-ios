import Foundation

protocol GetLegalDocumentUseCaseProtocol: Sendable {
    func execute(type: LegalDocumentType, lang: String) async throws(AppError) -> String
}

final class GetLegalDocumentUseCase: GetLegalDocumentUseCaseProtocol, Sendable {
    private let legalRepository: LegalRepositoryProtocol

    init(legalRepository: LegalRepositoryProtocol) {
        self.legalRepository = legalRepository
    }

    func execute(type: LegalDocumentType, lang: String) async throws(AppError) -> String {
        switch type {
        case .terms:
            return try await legalRepository.getTerms(lang: lang)
        case .privacy:
            return try await legalRepository.getPrivacy(lang: lang)
        }
    }
}
