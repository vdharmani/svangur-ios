import Foundation

struct FeaturedItem: Sendable, Equatable {
    let id: Int?
    let url: URL?
    let title: String?
}

/// Combined app-launch payload — categories, discount options, days, and the featured
/// carousel — in one round trip instead of four separate requests.
struct BootstrapData: Sendable, Equatable {
    let userCategories: [DealCategory]
    let ownerCategories: [DealCategory]
    let discountFilters: [DiscountUserFilter]
    let ownerDiscountOptions: [DiscountOwnerOption]
    let days: [DayItem]
    let featured: [FeaturedItem]
}
