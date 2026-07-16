import Foundation

/// Fetches the consumer deals feed (`GET /offers`) that backs Home's "All Deals" section.
protocol GetHomeDealsUseCaseProtocol: Sendable {
    func execute(
        latitude: Double?,
        longitude: Double?,
        categoryId: String?,
        discountFilter: String,
        day: String?,
        openNow: Bool?,
        lang: String,
        page: Int,
        limit: Int,
        deviceId: String
    ) async throws(AppError) -> [DealListing]
}

final class GetHomeDealsUseCase: GetHomeDealsUseCaseProtocol, Sendable {
    private let dealRepository: DealRepositoryProtocol

    init(dealRepository: DealRepositoryProtocol) {
        self.dealRepository = dealRepository
    }

    func execute(
        latitude: Double?,
        longitude: Double?,
        categoryId: String?,
        discountFilter: String,
        day: String?,
        openNow: Bool?,
        lang: String,
        page: Int,
        limit: Int,
        deviceId: String
    ) async throws(AppError) -> [DealListing] {
        try await dealRepository.listDeals(
            latitude: latitude,
            longitude: longitude,
            categoryId: categoryId,
            discountFilter: discountFilter,
            day: day,
            openNow: openNow,
            lang: lang,
            page: page,
            limit: limit,
            deviceId: deviceId
        )
    }
}
