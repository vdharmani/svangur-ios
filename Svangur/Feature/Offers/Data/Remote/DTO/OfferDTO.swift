import Foundation

// NOTE on custom `init(from:)`: Android's DTOs use kotlinx.serialization with
// `explicitNulls = false` — a Kotlin property with a default value (`val views: Int = 0`) may be
// omitted from the wire entirely, and the default is used. Swift's `Codable` synthesis has no
// concept of "default when key missing" for non-optional properties, so every DTO below that
// mirrors a Kotlin field with a default writes an explicit `init(from:)` using
// `decodeIfPresent(...) ?? default` — mirroring the pattern already established in
// `Feature/Deals/Data/Remote/DTO/DealDTO.swift` (`OfferStatsDTO`, etc.). Optional (`String?`)
// properties with no default need no special handling — Swift's synthesized/manual
// `decodeIfPresent` already yields `nil` when the key is absent.

// MARK: - Owner offer detail (GET /owner/offers/{id}, response of PUT /owner/offers/{id})

struct OwnerOfferStatsDTO: Codable, Sendable {
    let views: Int
    let clicks: Int

    enum CodingKeys: String, CodingKey {
        case views
        case clicks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        clicks = try container.decodeIfPresent(Int.self, forKey: .clicks) ?? 0
    }
}

struct OwnerOfferDetailCategoryDTO: Codable, Sendable {
    let id: Int64
    let nameEn: String?
    let nameIs: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nameEn = "name_en"
        case nameIs = "name_is"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn)
        nameIs = try container.decodeIfPresent(String.self, forKey: .nameIs)
    }
}

struct OwnerOfferDetailImageDTO: Codable, Sendable {
    let id: Int64
    let url: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

struct OwnerOfferDetailDTO: Codable, Sendable {
    let offerId: Int64
    let titleEn: String
    let titleIs: String?
    let descriptionEn: String?
    let descriptionIs: String?
    let category: OwnerOfferDetailCategoryDTO?
    let discountValue: String?
    let discountType: String?
    let discountLabelEn: String?
    let validDays: [String]
    let validTimeStart: String?
    let validTimeEnd: String?
    let images: [OwnerOfferDetailImageDTO]
    let imageUrl: String?
    let status: String?
    let stats: OwnerOfferStatsDTO?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case titleEn = "title_en"
        case titleIs = "title_is"
        case descriptionEn = "description_en"
        case descriptionIs = "description_is"
        case category
        case discountValue = "discount_value"
        case discountType = "discount_type"
        case discountLabelEn = "discount_label_en"
        case validDays = "valid_days"
        case validTimeStart = "valid_time_start"
        case validTimeEnd = "valid_time_end"
        case images
        case imageUrl = "image_url"
        case status
        case stats
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offerId = try container.decode(Int64.self, forKey: .offerId)
        titleEn = try container.decodeIfPresent(String.self, forKey: .titleEn) ?? ""
        titleIs = try container.decodeIfPresent(String.self, forKey: .titleIs)
        descriptionEn = try container.decodeIfPresent(String.self, forKey: .descriptionEn)
        descriptionIs = try container.decodeIfPresent(String.self, forKey: .descriptionIs)
        category = try container.decodeIfPresent(OwnerOfferDetailCategoryDTO.self, forKey: .category)
        discountValue = try container.decodeIfPresent(String.self, forKey: .discountValue)
        discountType = try container.decodeIfPresent(String.self, forKey: .discountType)
        discountLabelEn = try container.decodeIfPresent(String.self, forKey: .discountLabelEn)
        validDays = try container.decodeIfPresent([String].self, forKey: .validDays) ?? []
        validTimeStart = try container.decodeIfPresent(String.self, forKey: .validTimeStart)
        validTimeEnd = try container.decodeIfPresent(String.self, forKey: .validTimeEnd)
        images = try container.decodeIfPresent([OwnerOfferDetailImageDTO].self, forKey: .images) ?? []
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        stats = try container.decodeIfPresent(OwnerOfferStatsDTO.self, forKey: .stats)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct OwnerOfferEnvelopeDTO: Codable, Sendable {
    let data: OwnerOfferDetailDTO
}

// MARK: - Create offer response (POST /owner/offers)

struct CreateOfferDataDTO: Codable, Sendable {
    let offerId: Int64
    let isNewBoostEligible: Bool

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case isNewBoostEligible = "is_new_boost_eligible"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offerId = try container.decode(Int64.self, forKey: .offerId)
        isNewBoostEligible = try container.decodeIfPresent(Bool.self, forKey: .isNewBoostEligible) ?? false
    }
}

struct CreateOfferResponseDTO: Codable, Sendable {
    let data: CreateOfferDataDTO
}

// MARK: - Update offer response (PUT /owner/offers/{id})
// Verified against the live API contract: unlike create/get, update does NOT return a full
// offer envelope — it returns a small summary of the image edit that was applied.

struct UpdateOfferDataDTO: Codable, Sendable {
    let offerId: Int64
    let imagesRemoved: Int
    let imagesAdded: Int

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case imagesRemoved = "images_removed"
        case imagesAdded = "images_added"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offerId = try container.decode(Int64.self, forKey: .offerId)
        imagesRemoved = try container.decodeIfPresent(Int.self, forKey: .imagesRemoved) ?? 0
        imagesAdded = try container.decodeIfPresent(Int.self, forKey: .imagesAdded) ?? 0
    }
}

struct UpdateOfferResponseDTO: Codable, Sendable {
    let data: UpdateOfferDataDTO
}

// MARK: - Owner offer list (GET /owner/offers)

struct OwnerOfferListImageDTO: Codable, Sendable {
    let id: Int64
    let url: String

    enum CodingKeys: String, CodingKey {
        case id
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}

struct OwnerOfferListItemDTO: Codable, Sendable {
    let offerId: Int64
    let title: String
    let description: String?
    let discountLabel: String?
    let imageUrl: String?
    let images: [OwnerOfferListImageDTO]
    let validDays: [String]
    let validTimeStart: String?
    let validTimeEnd: String?
    let status: String?

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
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        offerId = try container.decode(Int64.self, forKey: .offerId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        discountLabel = try container.decodeIfPresent(String.self, forKey: .discountLabel)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        images = try container.decodeIfPresent([OwnerOfferListImageDTO].self, forKey: .images) ?? []
        validDays = try container.decodeIfPresent([String].self, forKey: .validDays) ?? []
        validTimeStart = try container.decodeIfPresent(String.self, forKey: .validTimeStart)
        validTimeEnd = try container.decodeIfPresent(String.self, forKey: .validTimeEnd)
        status = try container.decodeIfPresent(String.self, forKey: .status)
    }
}

struct OfferListPayloadDTO: Codable, Sendable {
    let items: [OwnerOfferListItemDTO]

    enum CodingKeys: String, CodingKey {
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([OwnerOfferListItemDTO].self, forKey: .items) ?? []
    }

    init(items: [OwnerOfferListItemDTO] = []) {
        self.items = items
    }
}

struct OfferListEnvelopeDTO: Codable, Sendable {
    let data: OfferListPayloadDTO
}

// MARK: - Analytics (GET /owner/offers/{id}/analytics)

struct OfferAnalyticsDTO: Codable, Sendable {
    let views: Int
    let viewsChangePct: Int
    let clicks: Int
    let clicksChangePct: Int
    let mapActions: Int
    let mapActionsChangePct: Int
    let callActions: Int
    let callActionsChangePct: Int
    let websiteActions: Int
    let websiteActionsChangePct: Int
    let period: String

    enum CodingKeys: String, CodingKey {
        case views
        case viewsChangePct = "views_change_pct"
        case clicks
        case clicksChangePct = "clicks_change_pct"
        case mapActions = "map_actions"
        case mapActionsChangePct = "map_actions_change_pct"
        case callActions = "call_actions"
        case callActionsChangePct = "call_actions_change_pct"
        case websiteActions = "website_actions"
        case websiteActionsChangePct = "website_actions_change_pct"
        case period
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        views = try container.decodeIfPresent(Int.self, forKey: .views) ?? 0
        viewsChangePct = try container.decodeIfPresent(Int.self, forKey: .viewsChangePct) ?? 0
        clicks = try container.decodeIfPresent(Int.self, forKey: .clicks) ?? 0
        clicksChangePct = try container.decodeIfPresent(Int.self, forKey: .clicksChangePct) ?? 0
        mapActions = try container.decodeIfPresent(Int.self, forKey: .mapActions) ?? 0
        mapActionsChangePct = try container.decodeIfPresent(Int.self, forKey: .mapActionsChangePct) ?? 0
        callActions = try container.decodeIfPresent(Int.self, forKey: .callActions) ?? 0
        callActionsChangePct = try container.decodeIfPresent(Int.self, forKey: .callActionsChangePct) ?? 0
        websiteActions = try container.decodeIfPresent(Int.self, forKey: .websiteActions) ?? 0
        websiteActionsChangePct = try container.decodeIfPresent(Int.self, forKey: .websiteActionsChangePct) ?? 0
        period = try container.decodeIfPresent(String.self, forKey: .period) ?? ""
    }
}

struct OfferAnalyticsEnvelopeDTO: Codable, Sendable {
    let data: OfferAnalyticsDTO
}
