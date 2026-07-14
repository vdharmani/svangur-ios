import Foundation

/// Mirrors Android's real `OfferSummary` / owner-offer detail shape (`/owner/offers*`).
/// Deliberately dual-language (`titleEn`/`titleIs`) instead of a single `title` — the
/// backend has no combined field. `categoryId` references the dynamic category list
/// fetched via `DealRepositoryProtocol.listOwnerCategories()` (Feature/Deals), NOT a
/// closed local enum. `discountValue` is a raw server string (percentage, "bogo", "custom",
/// etc.) — NOT a discriminated `OfferDiscount` enum; use `discountDisplayText` (in
/// `OfferUiMapper`) for a human-readable label.
///
/// `createdAt`/`updatedAt` are intentionally NOT modeled: Android's list DTO never provides
/// them, and the detail DTO's `created_at` is optional and unused by any Offers screen today.
struct Offer: Sendable, Equatable, Identifiable {
    let id: Int64
    let restaurantId: Int64?
    let titleEn: String
    let titleIs: String
    let descriptionEn: String?
    let descriptionIs: String?
    let categoryId: Int64?
    let discountValue: String?
    let customDiscountText: String?
    let validDays: Set<Weekday>
    let validTimeStart: TimeOfDay
    let validTimeEnd: TimeOfDay
    let status: OfferStatus?
    /// Derived from the raw wire `status == "active"` — independent of the `OfferStatus`
    /// enum above, matching Android's `OfferRepositoryImpl` mapping exactly.
    let isActive: Bool
    let heroImageUrl: URL?
    let imageUrls: [URL]
    let imageIds: [String]
    let views: Int
    let clicks: Int
    /// Only populated by the list endpoint (`GET /owner/offers`) — the detail endpoint's
    /// `stats` has no `call_actions`/`map_actions`/`website_actions` breakdown.
    let callActions: Int
    let mapActions: Int
    let websiteActions: Int
    /// Only populated by the list endpoint — the detail endpoint has no `restaurant` object.
    let restaurant: OfferRestaurantSummary?

    // Custom init (default values for the list-only fields above) so existing call sites that
    // predate them don't need updating — see CLAUDE.md's "custom init for default values" rule.
    init(
        id: Int64,
        restaurantId: Int64?,
        titleEn: String,
        titleIs: String,
        descriptionEn: String?,
        descriptionIs: String?,
        categoryId: Int64?,
        discountValue: String?,
        customDiscountText: String?,
        validDays: Set<Weekday>,
        validTimeStart: TimeOfDay,
        validTimeEnd: TimeOfDay,
        status: OfferStatus?,
        isActive: Bool,
        heroImageUrl: URL?,
        imageUrls: [URL],
        imageIds: [String],
        views: Int,
        clicks: Int,
        callActions: Int = 0,
        mapActions: Int = 0,
        websiteActions: Int = 0,
        restaurant: OfferRestaurantSummary? = nil
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.titleEn = titleEn
        self.titleIs = titleIs
        self.descriptionEn = descriptionEn
        self.descriptionIs = descriptionIs
        self.categoryId = categoryId
        self.discountValue = discountValue
        self.customDiscountText = customDiscountText
        self.validDays = validDays
        self.validTimeStart = validTimeStart
        self.validTimeEnd = validTimeEnd
        self.status = status
        self.isActive = isActive
        self.heroImageUrl = heroImageUrl
        self.imageUrls = imageUrls
        self.imageIds = imageIds
        self.views = views
        self.clicks = clicks
        self.callActions = callActions
        self.mapActions = mapActions
        self.websiteActions = websiteActions
        self.restaurant = restaurant
    }
}

/// Mirrors the `restaurant` object embedded in each item of `GET /owner/offers` — a restaurant
/// owner can eventually manage more than one restaurant, so each offer carries its own summary
/// rather than assuming a single app-wide restaurant.
struct OfferRestaurantSummary: Sendable, Equatable {
    let id: Int64
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let isOpenNow: Bool?
    let opensAt: String?
}
