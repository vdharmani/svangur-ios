import Foundation

extension LoginResponseDataDTO {
    func toDomain() -> AuthToken {
        AuthToken(
            token: token,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            ownerId: owner.id,
            ownerNameEn: owner.nameEn,
            ownerNameIs: owner.nameIs,
            ownerEmail: owner.email,
            ownerStatus: owner.status
        )
    }
}

extension RestaurantRegistration {
    /// Builds the `opening_hours` multipart field's JSON payload, matching the verified-live
    /// shape: `[{"day":"mon","start":"09:00","end":"22:00","is_open":true}, ...]` for open days,
    /// with `start`/`end` as JSON `null` (not a placeholder time) on closed days.
    func openingHoursJSON() -> String {
        let entries = Weekday.allCases.map { day -> OpeningHourWireDTO in
            let schedule = openingHours[day] ?? .standardOpen
            return OpeningHourWireDTO(
                day: day.shortName.lowercased(),
                start: schedule.isOpen ? schedule.openTime.formattedString : nil,
                end: schedule.isOpen ? schedule.closeTime.formattedString : nil,
                isOpen: schedule.isOpen
            )
        }
        guard let data = try? JSONEncoder().encode(entries),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

/// Wire-shape mirror used only to JSON-encode the "opening_hours" multipart text field with the
/// exact wire keys (day/start/end/is_open) — mirrors `EditRestaurant`'s `OpeningHourWireDTO`.
private struct OpeningHourWireDTO: Encodable, Sendable {
    let day: String
    let start: String?
    let end: String?
    let isOpen: Bool

    enum CodingKeys: String, CodingKey {
        case day
        case start
        case end
        case isOpen = "is_open"
    }
}

extension AuthToken {
    func toCachedDTO() -> CachedAuthTokenDTO {
        CachedAuthTokenDTO(
            token: token,
            expiresAt: expiresAt,
            ownerId: ownerId,
            ownerNameEn: ownerNameEn,
            ownerNameIs: ownerNameIs,
            ownerEmail: ownerEmail,
            ownerStatus: ownerStatus
        )
    }
}

struct CachedAuthTokenDTO: Codable, Sendable {
    let token: String
    let expiresAt: Date
    let ownerId: Int64
    let ownerNameEn: String
    let ownerNameIs: String
    let ownerEmail: String
    let ownerStatus: String

    func toDomain() -> AuthToken {
        AuthToken(
            token: token,
            expiresAt: expiresAt,
            ownerId: ownerId,
            ownerNameEn: ownerNameEn,
            ownerNameIs: ownerNameIs,
            ownerEmail: ownerEmail,
            ownerStatus: ownerStatus
        )
    }
}
