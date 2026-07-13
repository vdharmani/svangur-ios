import Foundation

struct DayItemDTO: Codable, Sendable {
    let key: String
    let label: String
    let shortLabel: String?

    enum CodingKeys: String, CodingKey {
        case key
        case label
        case shortLabel = "short_label"
    }

    // Mirrors Kotlin defaults: `key: String = ""`, `label: String = ""` (explicitNulls = false).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decodeIfPresent(String.self, forKey: .key) ?? ""
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        shortLabel = try container.decodeIfPresent(String.self, forKey: .shortLabel)
    }
}

/// Verified against the live server: `{ success, message, data: { current_day, items[] } }`.
struct DaysPayloadDTO: Codable, Sendable {
    let currentDay: String
    let items: [DayItemDTO]

    enum CodingKeys: String, CodingKey {
        case currentDay = "current_day"
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentDay = try container.decodeIfPresent(String.self, forKey: .currentDay) ?? ""
        items = try container.decodeIfPresent([DayItemDTO].self, forKey: .items) ?? []
    }
}

struct DaysResponseDTO: Codable, Sendable {
    let data: DaysPayloadDTO

    enum CodingKeys: String, CodingKey {
        case data
    }
}
