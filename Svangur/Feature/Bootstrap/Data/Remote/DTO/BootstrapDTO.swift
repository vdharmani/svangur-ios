import Foundation

/// The exact shape of a "featured" carousel entry is unconfirmed against a live, non-empty
/// response (the dev server returned `"featured": []` when this was verified) — every field
/// is optional so decoding never fails regardless of the real shape once populated.
struct FeaturedItemDTO: Codable, Sendable {
    let id: Int?
    let url: String?
    let title: String?
}

struct BootstrapPayloadDTO: Codable, Sendable {
    let categories: DealCategoriesPayloadDTO
    let discountOptions: DiscountOptionsPayloadDTO
    let days: DaysPayloadDTO
    let featured: [FeaturedItemDTO]

    enum CodingKeys: String, CodingKey {
        case categories
        case discountOptions = "discount_options"
        case days
        case featured
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decodeIfPresent(DealCategoriesPayloadDTO.self, forKey: .categories) ?? DealCategoriesPayloadDTO()
        discountOptions = try container.decodeIfPresent(DiscountOptionsPayloadDTO.self, forKey: .discountOptions) ?? DiscountOptionsPayloadDTO()
        days = try container.decode(DaysPayloadDTO.self, forKey: .days)
        featured = try container.decodeIfPresent([FeaturedItemDTO].self, forKey: .featured) ?? []
    }
}

struct BootstrapResponseDTO: Codable, Sendable {
    let data: BootstrapPayloadDTO

    enum CodingKeys: String, CodingKey {
        case data
    }
}
