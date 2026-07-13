import Foundation

enum AppRoute: Hashable, Sendable {
    case home
    case login
    case registerRestaurant
    case dealList
    case dealDetail(dealId: Int64)
    case restaurantDetail(restaurantId: Int64)
    case profile(userId: String)
    case settings
    case changePassword
    case editRestaurant
    case onboarding

    // MARK: - Offers (owner)
    case dashboard
    case addOffer
    case editOffer(offerId: Int64)
    case offerDetail(offerId: Int64)

    // MARK: - Search
    case search

    // MARK: - Location
    case selectLocation
    case confirmLocation(name: String)

    // MARK: - Auth
    case entry
    case forgotPassword
    case resetPassword(token: String)
}
