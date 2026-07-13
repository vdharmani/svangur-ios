import Foundation

protocol DealRepositoryProtocol: Sendable {
    func listDeals(
        latitude: Double?,
        longitude: Double?,
        categoryIds: [String],
        minDiscountPercent: Int?,
        day: String?
    ) async throws(AppError) -> [DealListing]

    func listCategories() async throws(AppError) -> [DealCategory]
    func listOwnerCategories() async throws(AppError) -> [DealCategory]
    func listDiscountFilters() async throws(AppError) -> [DiscountUserFilter]
    func listOwnerDiscountOptions() async throws(AppError) -> [DiscountOwnerOption]
    func getDeal(id: String) async throws(AppError) -> DealListing
    func trackView(id: String) async throws(AppError)
    func trackClick(id: String) async throws(AppError)
}

// NOTE: Swift protocol requirements cannot declare default parameter values (unlike
// the Kotlin `DealRepository` interface, whose params all default to `null` /
// `emptyList()`). Callers must pass all arguments explicitly; `DealRepositoryImpl`
// mirrors Android's defaults internally when forwarding to `DealEndpoint`.
