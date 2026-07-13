import Foundation

struct ProfileOpeningHourDTO: Sendable {
    let day: String
    let start: String?
    let end: String?
    let isOpen: Bool
}

extension ProfileOpeningHourDTO: Codable {
    enum CodingKeys: String, CodingKey {
        case day
        case start
        case end
        case isOpen = "is_open"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(String.self, forKey: .day)
        start = try container.decodeIfPresent(String.self, forKey: .start)
        end = try container.decodeIfPresent(String.self, forKey: .end)
        // Kotlin default: @SerialName("is_open") val isOpen: Boolean = true
        isOpen = try container.decodeIfPresent(Bool.self, forKey: .isOpen) ?? true
    }
}

struct ProfileDataDTO: Sendable {
    let nameEn: String
    let nameIs: String?
    let email: String?
    let phone: String?
    let descriptionEn: String?
    let descriptionIs: String?
    let address: String?
    let city: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let website: String?
    let openingHours: [ProfileOpeningHourDTO]
    let images: [String]
}

extension ProfileDataDTO: Codable {
    enum CodingKeys: String, CodingKey {
        case nameEn = "name_en"
        case nameIs = "name_is"
        case email
        case phone
        case descriptionEn = "description_en"
        case descriptionIs = "description_is"
        case address
        case city
        case country
        case latitude
        case longitude
        case website
        case openingHours = "opening_hours"
        case images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Kotlin defaults: nameEn = "", openingHours = emptyList(), images = emptyList(); everything
        // else defaults to null. Mirrored here via decodeIfPresent + fallback, matching
        // ignoreUnknownKeys/explicitNulls = false behavior for missing keys.
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn) ?? ""
        nameIs = try container.decodeIfPresent(String.self, forKey: .nameIs)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        descriptionEn = try container.decodeIfPresent(String.self, forKey: .descriptionEn)
        descriptionIs = try container.decodeIfPresent(String.self, forKey: .descriptionIs)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        openingHours = try container.decodeIfPresent([ProfileOpeningHourDTO].self, forKey: .openingHours) ?? []
        images = try container.decodeIfPresent([String].self, forKey: .images) ?? []
    }
}

struct ProfileEnvelopeDTO: Codable, Sendable {
    let data: ProfileDataDTO
}
