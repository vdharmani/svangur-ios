import Foundation

struct OfferUi: Equatable, Identifiable, Sendable {
    let id: Int64
    let title: String
    let description: String
    let categoryDisplayText: String
    let discountBadgeText: String
    let validDaysText: String
    let validDayNames: [String]
    let validTimeText: String
    let imageUrls: [URL]
    let status: OfferStatus?
    let isActive: Bool

    // Enriched from the restaurant profile + analytics endpoint — nil until those
    // secondary fetches resolve (or if they fail/return no value). See `OfferUiMapper`.
    let restaurantName: String?
    let restaurantPhone: String?
    let restaurantWebsite: String?
    let latitude: Double?
    let longitude: Double?
    let analytics: OfferAnalyticsUi?

    // Custom init (default values for the enrichment fields above) so existing call sites that
    // predate them don't need updating — see CLAUDE.md's "custom init for default values" rule.
    init(
        id: Int64,
        title: String,
        description: String,
        categoryDisplayText: String,
        discountBadgeText: String,
        validDaysText: String,
        validDayNames: [String],
        validTimeText: String,
        imageUrls: [URL],
        status: OfferStatus?,
        isActive: Bool,
        restaurantName: String? = nil,
        restaurantPhone: String? = nil,
        restaurantWebsite: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        analytics: OfferAnalyticsUi? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.categoryDisplayText = categoryDisplayText
        self.discountBadgeText = discountBadgeText
        self.validDaysText = validDaysText
        self.validDayNames = validDayNames
        self.validTimeText = validTimeText
        self.imageUrls = imageUrls
        self.status = status
        self.isActive = isActive
        self.restaurantName = restaurantName
        self.restaurantPhone = restaurantPhone
        self.restaurantWebsite = restaurantWebsite
        self.latitude = latitude
        self.longitude = longitude
        self.analytics = analytics
    }
}
