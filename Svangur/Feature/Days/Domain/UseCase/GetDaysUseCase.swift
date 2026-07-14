import Foundation

protocol GetDaysUseCaseProtocol: Sendable {
    func execute(lang: String, tz: String) async throws(AppError) -> [DayItem]
}

final class GetDaysUseCase: GetDaysUseCaseProtocol, Sendable {
    private let daysRepository: DaysRepositoryProtocol

    init(daysRepository: DaysRepositoryProtocol) {
        self.daysRepository = daysRepository
    }

    func execute(lang: String, tz: String) async throws(AppError) -> [DayItem] {
        try await daysRepository.getDays(lang: lang, tz: tz)
    }
}
