import Foundation

protocol DaysRepositoryProtocol: Sendable {
    func getDays(lang: String, tz: String) async throws(AppError) -> [DayItem]
}
