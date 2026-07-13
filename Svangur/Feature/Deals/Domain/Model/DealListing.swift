import Foundation

struct DealListing: Sendable, Equatable {
    let id: String
    let restaurantId: String?
    let restaurantName: String?
    let categoryId: String?
    let categoryName: String?
    let title: String
    let description: String?
    let discountType: String?
    let discountPercent: Int?
    let customDiscountText: String?
    let validTimeStart: String?
    let validTimeEnd: String?
    let validDays: [Int]
    let heroImageUrl: String?
    let imageUrls: [String]
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let isOpenNow: Bool?
    let opensAt: String?
    let rating: Double?
    let phone: String?
    let website: String?
    let views: Int
    let clicks: Int

    init(
        id: String,
        restaurantId: String?,
        restaurantName: String?,
        categoryId: String?,
        categoryName: String?,
        title: String,
        description: String?,
        discountType: String?,
        discountPercent: Int?,
        customDiscountText: String?,
        validTimeStart: String?,
        validTimeEnd: String?,
        validDays: [Int],
        heroImageUrl: String?,
        imageUrls: [String] = [],
        address: String? = nil,
        latitude: Double?,
        longitude: Double?,
        distanceKm: Double?,
        isOpenNow: Bool?,
        opensAt: String? = nil,
        rating: Double?,
        phone: String? = nil,
        website: String? = nil,
        views: Int = 0,
        clicks: Int = 0
    ) {
        self.id = id
        self.restaurantId = restaurantId
        self.restaurantName = restaurantName
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.title = title
        self.description = description
        self.discountType = discountType
        self.discountPercent = discountPercent
        self.customDiscountText = customDiscountText
        self.validTimeStart = validTimeStart
        self.validTimeEnd = validTimeEnd
        self.validDays = validDays
        self.heroImageUrl = heroImageUrl
        self.imageUrls = imageUrls
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.distanceKm = distanceKm
        self.isOpenNow = isOpenNow
        self.opensAt = opensAt
        self.rating = rating
        self.phone = phone
        self.website = website
        self.views = views
        self.clicks = clicks
    }
}
