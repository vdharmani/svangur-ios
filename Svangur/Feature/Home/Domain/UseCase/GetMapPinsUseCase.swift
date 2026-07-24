import Foundation

/// Fetches the unfiltered consumer deals feed (`GET /offers?lang={lang}`) used to place pins on
/// the map. Unlike `GetHomeDealsUseCase`, this intentionally omits `lat`/`lng`/`device_id` —
/// the map shows every deal with a coordinate, not a location-sorted, impression-tracked feed.
protocol GetMapPinsUseCaseProtocol: Sendable {
    func execute(lang: String) async throws(AppError) -> [DealListing]
}

final class GetMapPinsUseCase: GetMapPinsUseCaseProtocol, Sendable {
    private let dealRepository: DealRepositoryProtocol

    init(dealRepository: DealRepositoryProtocol) {
        self.dealRepository = dealRepository
    }

    func execute(lang: String) async throws(AppError) -> [DealListing] {
        try await dealRepository.listDeals(
            latitude: nil,
            longitude: nil,
            categoryId: nil,
            discountFilter: nil,
            day: nil,
            openNow: nil,
            lang: lang,
            page: nil,
            limit: nil,
            deviceId: nil
        )
    }
}
