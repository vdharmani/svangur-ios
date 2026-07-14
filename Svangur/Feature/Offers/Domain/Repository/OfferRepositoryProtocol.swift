import Foundation

protocol OfferRepositoryProtocol: Sendable {
    func getMyOffers(page: Int, limit: Int) async throws(AppError) -> PaginatedResult<Offer>
    func getOffer(id: Int64) async throws(AppError) -> Offer
    /// Matches Android's `OfferRepository.createOffer(draft): ApiResult<Unit>` — the created
    /// offer's ID is not returned to callers; screens that need the fresh data reload via
    /// `getMyOffers()` / `getOffer(id:)`.
    func createOffer(_ draft: OfferDraft) async throws(AppError)
    /// Matches Android's `OfferRepository.updateOffer(draft): ApiResult<Unit>`.
    func updateOffer(id: Int64, draft: OfferDraft) async throws(AppError)
    func deleteOffer(id: Int64) async throws(AppError)
    func getAnalytics(id: Int64) async throws(AppError) -> OfferAnalytics
}
