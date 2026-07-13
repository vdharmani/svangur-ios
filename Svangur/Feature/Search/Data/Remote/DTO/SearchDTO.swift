import Foundation

// MARK: - Search Response DTOs

struct SearchRestaurantDTO: Codable, Sendable {
    let id: Int
    let name: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let distanceKm: Double?
    let isOpenNow: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case latitude
        case longitude
        case distanceKm = "distance_km"
        case isOpenNow = "is_open_now"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        distanceKm = try container.decodeIfPresent(Double.self, forKey: .distanceKm)
        isOpenNow = try container.decodeIfPresent(Bool.self, forKey: .isOpenNow)
    }
}

struct SearchOfferImageDTO: Codable, Sendable {
    let id: Int
    let url: String

    enum CodingKeys: String, CodingKey {
        case id
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

struct SearchOfferDTO: Codable, Sendable {
    let offerId: Int
    let title: String
    let description: String?
    let discountLabel: String?
    let imageUrl: String?
    let images: [SearchOfferImageDTO]
    let validDays: [String]
    let validTimeStart: String?
    let validTimeEnd: String?
    let restaurant: SearchRestaurantDTO?

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case title
        case description
        case discountLabel = "discount_label"
        case imageUrl = "image_url"
        case images
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
        images = try container.decodeIfPresent([SearchOfferImageDTO].self, forKey: .images) ?? []
        validDays = try container.decodeIfPresent([String].self, forKey: .validDays) ?? []
        validTimeStart = try container.decodeIfPresent(String.self, forKey: .validTimeStart)
        validTimeEnd = try container.decodeIfPresent(String.self, forKey: .validTimeEnd)
        restaurant = try container.decodeIfPresent(SearchRestaurantDTO.self, forKey: .restaurant)
    }
}

struct SearchResponsePayloadDTO: Codable, Sendable {
    let items: [SearchOfferDTO]
    let total: Int
    let page: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case totalPages = "total_pages"
    }

    init() {
        items = []
        total = 0
        page = 1
        totalPages = 1
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([SearchOfferDTO].self, forKey: .items) ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
    }
}

struct SearchResponseEnvelopeDTO: Codable, Sendable {
    let data: SearchResponsePayloadDTO

    enum CodingKeys: String, CodingKey {
        case data
    }

    init() {
        data = SearchResponsePayloadDTO()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent(SearchResponsePayloadDTO.self, forKey: .data) ?? SearchResponsePayloadDTO()
    }
}

// MARK: - Recent Search DTOs

struct RecentSearchDTO: Codable, Sendable {
    let query: String
    let kind: String
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case query
        case kind
        case latitude
        case longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = try container.decode(String.self, forKey: .query)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "offer"
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    }
}

struct RecentSearchesPayloadDTO: Codable, Sendable {
    let items: [RecentSearchDTO]

    enum CodingKeys: String, CodingKey {
        case items
    }

    init() {
        items = []
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([RecentSearchDTO].self, forKey: .items) ?? []
    }
}

struct RecentSearchEnvelopeDTO: Codable, Sendable {
    let data: RecentSearchesPayloadDTO

    enum CodingKeys: String, CodingKey {
        case data
    }

    init() {
        data = RecentSearchesPayloadDTO()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent(RecentSearchesPayloadDTO.self, forKey: .data) ?? RecentSearchesPayloadDTO()
    }
}

// MARK: - Add Recent Search Request DTO

struct AddRecentSearchRequestDTO: Codable, Sendable {
    let deviceId: String
    let query: String
    let kind: String
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case query
        case kind
        case latitude
        case longitude
    }

    init(deviceId: String, query: String, kind: String = "offer", latitude: Double? = nil, longitude: Double? = nil) {
        self.deviceId = deviceId
        self.query = query
        self.kind = kind
        self.latitude = latitude
        self.longitude = longitude
    }
}
