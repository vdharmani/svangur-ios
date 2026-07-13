import Foundation

protocol EditRestaurantRepositoryProtocol: Sendable {
    func getProfile() async throws(AppError) -> RestaurantEditData
    func updateProfile(params: ProfileUpdateParams) async throws(AppError)
    /// Returns the raw JSON body — the real response shape is unverified (requires owner
    /// credentials this environment doesn't have). Replace with a typed DTO once confirmed.
    func getDashboardRaw(page: Int, limit: Int, lang: String) async throws(AppError) -> Data
}
