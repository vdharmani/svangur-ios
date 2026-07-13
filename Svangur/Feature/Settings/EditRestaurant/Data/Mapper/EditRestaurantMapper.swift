import Foundation

extension ProfileDataDTO {
    /// Mirrors Android's `ProfileDataDto.toRestaurantEditData()`.
    func toDomain() -> RestaurantEditData {
        // Day-code strings are "mon","tue","wed","thu","fri","sat","sun" — matching
        // `Weekday.shortName.lowercased()`.
        let serverHoursByDayCode = Dictionary(
            openingHours.map { ($0.day.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let allSchedules = Weekday.allCases.map { weekday -> EditDaySchedule in
            let dayCode = weekday.shortName.lowercased()
            guard let dto = serverHoursByDayCode[dayCode] else {
                return EditDaySchedule(day: weekday, openTime: "09:00", closeTime: "22:00", isClosed: false)
            }
            return EditDaySchedule(
                day: weekday,
                openTime: dto.start ?? "09:00",
                closeTime: dto.end ?? "22:00",
                isClosed: !dto.isOpen
            )
        }

        return RestaurantEditData(
            nameEn: nameEn,
            nameIs: nameIs ?? nameEn,
            adminEmail: email ?? "",
            phoneNumber: phone ?? "",
            descriptionEn: descriptionEn ?? "",
            descriptionIs: descriptionIs ?? "",
            address: address ?? "",
            city: city ?? "",
            country: country ?? "Iceland",
            latitude: latitude,
            longitude: longitude,
            website: website ?? "",
            openingHours: allSchedules,
            restaurantImages: images
        )
    }
}
