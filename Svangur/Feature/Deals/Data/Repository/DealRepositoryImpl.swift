import Foundation

/// The sentinel `id` used by the backend's "All" filter chip — excluded when mapping
/// `userFilters` into `DealCategory`. Mirrors Android's `DealRepositoryImpl.ALL_FILTER_ID`.
private let dealAllFilterID = 1

final class DealRepositoryImpl: DealRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func listDeals(
        latitude: Double?,
        longitude: Double?,
        categoryIds: [String],
        minDiscountPercent: Int?,
        day: String?
    ) async throws(AppError) -> [DealListing] {
        try await apiCall {
            let envelope: DealListEnvelopeDTO = try await apiClient.execute(
                DealEndpoint.listDeals(
                    lat: latitude,
                    lng: longitude,
                    categoryId: categoryIds.first,
                    discountFilter: discountFilter(for: minDiscountPercent),
                    day: day,
                    openNow: nil,
                    lang: nil,
                    page: nil,
                    limit: nil,
                    deviceId: nil
                )
            )
            return envelope.data.items.map { $0.toDomain() }
        }
    }

    func listCategories() async throws(AppError) -> [DealCategory] {
        try await apiCall {
            let envelope: DealCategoriesEnvelopeDTO = try await apiClient.execute(DealEndpoint.listCategories)
            return envelope.data.userFilters
                .filter { $0.id != dealAllFilterID }
                .map { $0.toDomain() }
        }
    }

    func listOwnerCategories() async throws(AppError) -> [DealCategory] {
        try await apiCall {
            let envelope: DealCategoriesEnvelopeDTO = try await apiClient.execute(DealEndpoint.listCategories)
            return envelope.data.ownerOptions.map { $0.toDomain() }
        }
    }

    func listDiscountFilters() async throws(AppError) -> [DiscountUserFilter] {
        try await apiCall {
            let envelope: DiscountOptionsEnvelopeDTO = try await apiClient.execute(DealEndpoint.listDiscountOptions)
            return envelope.data.userFilters.map { $0.toDomain() }
        }
    }

    func listOwnerDiscountOptions() async throws(AppError) -> [DiscountOwnerOption] {
        try await apiCall {
            let envelope: DiscountOptionsEnvelopeDTO = try await apiClient.execute(DealEndpoint.listDiscountOptions)
            return envelope.data.ownerOptions.map { $0.toDomain() }
        }
    }

    func getDeal(id: String) async throws(AppError) -> DealListing {
        try await apiCall {
            let envelope: DealEnvelopeDTO = try await apiClient.execute(
                DealEndpoint.getDeal(id: id, lang: nil, lat: nil, lng: nil, deviceId: nil)
            )
            return envelope.data.toDomain()
        }
    }

    /// Matches Android exactly: `DealRepositoryImpl.trackView` never calls the API —
    /// it's a client-only no-op (`ApiResult.Success(Unit)`).
    func trackView(id: String) async throws(AppError) {
        return
    }

    func trackClick(id: String) async throws(AppError) {
        try await apiCall {
            let _: EmptyResponse = try await apiClient.execute(
                DealEndpoint.trackClick(id: id, body: TrackClickRequestDTO(deviceId: nil))
            )
        }
    }

    // MARK: - Private

    /// Mirrors Android's `Int.toDiscountFilter()`: >=30 -> "30_plus", >=20 -> "20_plus", else -> "all".
    private func discountFilter(for minDiscountPercent: Int?) -> String? {
        guard let minDiscountPercent else { return nil }
        if minDiscountPercent >= 30 { return "30_plus" }
        if minDiscountPercent >= 20 { return "20_plus" }
        return "all"
    }
}

private struct EmptyResponse: Decodable, Sendable {
    init(from decoder: Decoder) throws {}
}
