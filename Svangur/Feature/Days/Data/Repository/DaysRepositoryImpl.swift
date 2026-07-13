import Foundation

final class DaysRepositoryImpl: DaysRepositoryProtocol, Sendable {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getDays(lang: String, tz: String) async throws(AppError) -> [DayItem] {
        try await apiCall {
            let response: DaysResponseDTO = try await apiClient.execute(
                DaysEndpoint.getDays(lang: lang, tz: tz)
            )
            return response.data.items.map { $0.toDomain(currentDay: response.data.currentDay) }
        }
    }
}
