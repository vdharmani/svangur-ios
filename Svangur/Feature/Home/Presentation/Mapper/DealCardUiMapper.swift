import Foundation

extension Offer {
    func toDealCard(
        restaurantName: String = "Local Restaurant",
        distance: String = "1.2 km"
    ) -> DealCardUi {
        DealCardUi(
            id: id,
            restaurantName: restaurantName,
            title: titleEn,
            discountBadge: discountDisplayText,
            categoryName: categoryId.map { "Category #\($0)" } ?? "Other",
            distance: distance,
            validTimeText: "\(validTimeStart.formatted24h)–\(validTimeEnd.formatted24h)",
            imageUrl: heroImageUrl ?? imageUrls.first,
            isOpenNow: Self.isCurrentlyOpen(validDays: validDays, from: validTimeStart, until: validTimeEnd)
        )
    }

    static func isCurrentlyOpen(
        validDays: Set<Weekday>,
        from: TimeOfDay,
        until: TimeOfDay
    ) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekdayComponent = calendar.component(.weekday, from: now)

        let mapped: Weekday? = switch weekdayComponent {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        case 7: .saturday
        default: nil
        }
        guard let mapped, validDays.contains(mapped) else { return false }

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let current = hour * 60 + minute
        return current >= from.minutesSinceMidnight && current <= until.minutesSinceMidnight
    }
}
