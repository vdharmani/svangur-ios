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
            throw .validation(message: "Please fix the errors in the form before saving.")
        }
        try await offerRepository.createOffer(draft)
    }
}
