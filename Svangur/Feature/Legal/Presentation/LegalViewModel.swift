import SwiftUI
import Combine

@MainActor
final class LegalViewModel: ObservableObject {
    @Published private(set) var state: LegalUiState = .idle

    let documentType: LegalDocumentType
    private let getLegalDocumentUseCase: GetLegalDocumentUseCaseProtocol

    init(documentType: LegalDocumentType, getLegalDocumentUseCase: GetLegalDocumentUseCaseProtocol) {
        self.documentType = documentType
        self.getLegalDocumentUseCase = getLegalDocumentUseCase
    }

    func onAppear(lang: String) async {
        guard state == .idle else { return }
        await load(lang: lang)
    }

    func refresh(lang: String) async {
        await load(lang: lang)
    }

    private func load(lang: String) async {
        state = .loading
        do throws(AppError) {
            let html = try await getLegalDocumentUseCase.execute(type: documentType, lang: lang)
            state = .loaded(html: html)
        } catch {
            state = .error(error.displayMessage)
        }
    }
}

// MARK: - Preview Factory

extension LegalViewModel {
    @MainActor
    static func previewInstance(
        documentType: LegalDocumentType = .terms,
        state: LegalUiState = .idle
    ) -> LegalViewModel {
        let vm = LegalViewModel(
            documentType: documentType,
            getLegalDocumentUseCase: FakeGetLegalDocumentUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeGetLegalDocumentUseCase: GetLegalDocumentUseCaseProtocol {
    func execute(type: LegalDocumentType, lang: String) async throws(AppError) -> String {
        "<html><body><h1>\(type.title)</h1><p>Preview content.</p></body></html>"
    }
}
