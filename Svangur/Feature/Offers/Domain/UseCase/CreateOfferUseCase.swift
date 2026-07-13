protocol CreateOfferUseCaseProtocol: Sendable {
    func execute(draft: OfferDraft) async throws(AppError)
}

final class CreateOfferUseCase: CreateOfferUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol
    private let validateDraft: ValidateOfferDraftUseCaseProtocol

    init(
        offerRepository: OfferRepositoryProtocol,
        validateDraft: ValidateOfferDraftUseCaseProtocol
    ) {
        self.offerRepository = offerRepository
        self.validateDraft = validateDraft
    }

    func execute(draft: OfferDraft) async throws(AppError) {
        let errors = validateDraft.execute(draft)
        guard errors.isValid else {
            throw .validation(message: "form.error.invalid_draft")
        }
        try await offerRepository.createOffer(draft)
    }
}
