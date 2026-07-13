import Foundation

// MARK: - Offer Detail (GET /offers/{id})

struct OfferDetailCategoryDTO: Codable, Sendable {
    let id: Int?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}

struct OfferDetailImageDTO: Codable, Sendable {
    let id: Int
    let url: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

struct OfferDetailLocationDTO: Codable, Sendable {
    let lat: Double?
    let lng: Double?
    let address: String?

    enum CodingKeys: String, CodingKey {
        case lat
        case lng
        case address
    }
}

struct OfferDetailRestaurantDTO: Codable, Sendable {
    let id: Int?
    let name: String?
    let phone: String?
    let website: String?
    let location: OfferDetailLocationDTO?
    let distanceKm: Double?
    let isOpenNow: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case phone
        case website
        case location
        case distanceKm = "distance_km"
        case isOpenNow = "is_open_now"
    }
}

struct OfferStatsDTO: Codable, Sendable {
    let views: Int
    let clicks: Int
    let callActions: Int
    let mapActions: Int
    let websiteActions: Int

    enum CodingKeys: String, CodingKey {
        case views
        case clicks
        case callActions = "call_actions"
        case mapActions = "map_actions"
        case websiteActions = "website_actions"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        clicks = try container.decodeIfPresent(Int.self, forKey: .clicks) ?? 0
        callActions = try container.decodeIfPresent(Int.self, forKey: .callActions) ?? 0
        mapActions = try container.decodeIfPresent(Int.self, forKey: .mapActions) ?? 0
        websiteActions = try container.decodeIfPresent(Int.self, forKey: .websiteActions) ?? 0
    }
}

struct OfferDetailDTO: Codable, Sendable {
    let offerId: Int
    let title: String
    let description: String?
    let discountLabel: String?
    let category: OfferDetailCategoryDTO?
    let validDays: [String]
    let validTimeStart: String?
    let validTimeEnd: String?
    let images: [OfferDetailImageDTO]
    let stats: OfferStatsDTO?
    let restaurant: OfferDetailRestaurantDTO?

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case title
        case description
        case discountLabel = "discount_label"
        case category
        case validDays = "valid_days"
        case validTimeStart = "valid_time_start"
        case validTimeEnd = "valid_time_end"
        case images
        case stats
        case restaurant
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offerId = try container.decode(Int.self, forKey: .offerId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        discountLabel = try container.decodeIfPresent(String.self, forKey: .discountLabel)
        category = try container.decodeIfPresent(OfferDetailCategoryDTO.self, forKey: .category)
        validDays = try container.decodeIfPresent([String].self, forKey: .validDays) ?? []
        validTimeStart = try container.decodeIfPresent(String.self, forKey: .validTimeStart)
        validTimeEnd = try container.decodeIfPresent(String.self, forKey: .validTimeEnd)
        images = try container.decodeIfPresent([OfferDetailImageDTO].self, forKey: .images) ?? []
        stats = try container.decodeIfPresent(OfferStatsDTO.self, forKey: .stats)
        restaurant = try container.decodeIfPresent(OfferDetailRestaurantDTO.self, forKey: .restaurant)
    }
}

struct DealEnvelopeDTO: Codable, Sendable {
    let data: OfferDetailDTO

    enum CodingKeys: String, CodingKey {
        case data
    }
}

// MARK: - Feed / List (GET /offers)

struct FeedRestaurantDTO: Codable, Sendable {
    let id: Int?
    let name: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let isOpenNow: Bool?
    let opensAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case latitude
        case longitude
        case distanceKm = "distance_km"
        case isOpenNow = "is_open_now"
        case opensAt = "opens_at"
    }
}

struct FeedItemDTO: Codable, Sendable {
    let offerId: Int
    let title: String
    let description: String?
    let discountLabel: String?
    let imageUrl: String?
    let validDays: [String]
    let validTimeStart: String?
    let validTimeEnd: String?
    let restaurant: FeedRestaurantDTO?

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case title
        case description
        case discountLabel = "discount_label"
        case imageUrl = "image_url"
        case validDays = "valid_days"
        case validTimeStart = "valid_time_start"
        case validTimeEnd = "valid_time_end"
        case restaurant
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offerId = try container.decode(Int.self, forKey: .offerId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        discountLabel = try container.decodeIfPresent(String.self, forKey: .discountLabel)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        validDays = try container.decodeIfPresent([String].self, forKey: .validDays) ?? []
        validTimeStart = try container.decodeIfPresent(String.self, forKey: .validTimeStart)
        validTimeEnd = try container.decodeIfPresent(String.self, forKey: .validTimeEnd)
        restaurant = try container.decodeIfPresent(FeedRestaurantDTO.self, forKey: .restaurant)
    }
}

struct DealListPayloadDTO: Codable, Sendable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
    let items: [FeedItemDTO]

    enum CodingKeys: String, CodingKey {
        case page
        case limit
        case total
        case totalPages = "total_pages"
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        limit = try container.decodeIfPresent(Int.self, forKey: .limit) ?? 20
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        items = try container.decodeIfPresent([FeedItemDTO].self, forKey: .items) ?? []
    }
}

struct DealListEnvelopeDTO: Codable, Sendable {
    let data: DealListPayloadDTO

    enum CodingKeys: String, CodingKey {
        case data
    }
}

// MARK: - Categories (GET /categories)

struct DealCategoryFilterDTO: Codable, Sendable {
    let id: Int
    let label: String
    let iconUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case iconUrl = "icon_url"
    }
}

struct DealCategoriesPayloadDTO: Codable, Sendable {
    let userFilters: [DealCategoryFilterDTO]
    let ownerOptions: [DealCategoryFilterDTO]

    enum CodingKeys: String, CodingKey {
        case userFilters = "user_filters"
        case ownerOptions = "owner_options"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userFilters = try container.decodeIfPresent([DealCategoryFilterDTO].self, forKey: .userFilters) ?? []
        ownerOptions = try container.decodeIfPresent([DealCategoryFilterDTO].self, forKey: .ownerOptions) ?? []
    }

    init(userFilters: [DealCategoryFilterDTO] = [], ownerOptions: [DealCategoryFilterDTO] = []) {
        self.userFilters = userFilters
        self.ownerOptions = ownerOptions
    }
}

struct DealCategoriesEnvelopeDTO: Codable, Sendable {
    let data: DealCategoriesPayloadDTO

    enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent(DealCategoriesPayloadDTO.self, forKey: .data) ?? DealCategoriesPayloadDTO()
    }

    init(data: DealCategoriesPayloadDTO = DealCategoriesPayloadDTO()) {
        self.data = data
    }
}

// MARK: - Discount Options (GET /discount-options)
// Verified against the live server: user_filters and owner_options have DIFFERENT shapes —
// user_filters items carry `key` (the consumer filter value, e.g. "20_plus"), owner_options
// items carry `value`/`kind` (what a restaurant sets on an offer's `discount_value`/type).

struct DiscountUserFilterDTO: Codable, Sendable {
    let id: Int
    let key: String
    let label: String
}

struct DiscountOwnerOptionDTO: Codable, Sendable {
    let id: Int
    let value: String
    let kind: String
    let label: String
}

struct DiscountOptionsPayloadDTO: Codable, Sendable {
    let userFilters: [DiscountUserFilterDTO]
    let ownerOptions: [DiscountOwnerOptionDTO]

    enum CodingKeys: String, CodingKey {
        case userFilters = "user_filters"
        case ownerOptions = "owner_options"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userFilters = try container.decodeIfPresent([DiscountUserFilterDTO].self, forKey: .userFilters) ?? []
        ownerOptions = try container.decodeIfPresent([DiscountOwnerOptionDTO].self, forKey: .ownerOptions) ?? []
    }

    init(userFilters: [DiscountUserFilterDTO] = [], ownerOptions: [DiscountOwnerOptionDTO] = []) {
        self.userFilters = userFilters
        self.ownerOptions = ownerOptions
    }
}

struct DiscountOptionsEnvelopeDTO: Codable, Sendable {
    let data: DiscountOptionsPayloadDTO

    enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent(DiscountOptionsPayloadDTO.self, forKey: .data) ?? DiscountOptionsPayloadDTO()
    }

    init(data: DiscountOptionsPayloadDTO = DiscountOptionsPayloadDTO()) {
        self.data = data
    }
}

// MARK: - Click Tracking (POST /offers/{id}/click)

struct TrackClickRequestDTO: Codable, Sendable {
    let deviceId: String?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
    }
}
