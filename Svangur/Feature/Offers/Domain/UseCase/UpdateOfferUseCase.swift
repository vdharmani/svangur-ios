protocol UpdateOfferUseCaseProtocol: Sendable {
    func execute(id: Int64, draft: OfferDraft) async throws(AppError)
}

final class UpdateOfferUseCase: UpdateOfferUseCaseProtocol, Sendable {
    private let offerRepository: OfferRepositoryProtocol
    private let validateDraft: ValidateOfferDraftUseCaseProtocol

    init(
        offerRepository: OfferRepositoryProtocol,
        validateDraft: ValidateOfferDraftUseCaseProtocol
    ) {
        self.offerRepository = offerRepository
        self.validateDraft = validateDraft
    }

    func execute(id: Int64, draft: OfferDraft) async throws(AppError) {
        guard id > 0 else {
            throw .validation(message: "Offer ID must be positive")
        }
        let errors = validateDraft.execute(draft)
        guard errors.isValid else {
            throw .validation(message: "Please fix the errors in the form before saving.")
        }
        try await offerRepository.updateOffer(id: id, draft: draft)
    }
}
