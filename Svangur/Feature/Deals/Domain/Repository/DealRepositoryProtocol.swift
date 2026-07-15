import Foundation

protocol DealRepositoryProtocol: Sendable {
    /// Maps directly onto `GET /offers` (the consumer feed — auto-records impressions when
    /// `deviceId` is supplied). `discountFilter` takes the server's literal filter key
    /// ("all" | "20_plus" | "30_plus" | "2_for_1") rather than a numeric threshold, since
    /// "2_for_1" has no percentage equivalent.
    func listDeals(
        latitude: Double?,
        longitude: Double?,
        categoryId: String?,
        discountFilter: String?,
        day: String?,
        openNow: Bool?,
        lang: String?,
        page: Int?,
        limit: Int?,
        deviceId: String?
    ) async throws(AppError) -> [DealListing]

    func listCategories(lang: String) async throws(AppError) -> [DealCategory]
    func listOwnerCategories(lang: String) async throws(AppError) -> [DealCategory]
    func listDiscountFilters(lang: String) async throws(AppError) -> [DiscountUserFilter]
    func listOwnerDiscountOptions(lang: String) async throws(AppError) -> [DiscountOwnerOption]
    func getDeal(id: String) async throws(AppError) -> DealListing
    func trackView(id: String) async throws(AppError)
    func trackClick(id: String) async throws(AppError)
}

// NOTE: Swift protocol requirements cannot declare default parameter values (unlike
// the Kotlin `DealRepository` interface, whose params all default to `null` /
// `emptyList()`). Callers must pass all arguments explicitly; `DealRepositoryImpl`
// mirrors Android's defaults internally when forwarding to `DealEndpoint`.
