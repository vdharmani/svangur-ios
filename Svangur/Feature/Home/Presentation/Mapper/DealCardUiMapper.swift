import Foundation

extension DealListing {
    func toDealCard() -> DealCardUi {
        DealCardUi(
            id: Int64(id) ?? 0,
            restaurantName: restaurantName ?? "",
            title: title,
            discountBadge: customDiscountText ?? "",
            categoryName: categoryName ?? "",
            distance: distanceKm.map { String(format: "%.1f km", $0) } ?? "",
            validTimeText: "\(dealCardTime(validTimeStart))–\(dealCardTime(validTimeEnd))",
            imageUrl: heroImageUrl.flatMap(URL.init(string:)),
            isOpenNow: isOpenNow ?? false
        )
    }
}

/// The feed's `valid_time_start`/`valid_time_end` are raw wire strings ("HH:mm" or
/// "HH:mm:ss") — `TimeOfDay`'s parser only accepts a 2-part "HH:mm" string, so this formats
/// just the "HH:mm" prefix and falls back to the raw string if it doesn't parse.
private func dealCardTime(_ raw: String?) -> String {
    guard let raw, let time = TimeOfDay(string: String(raw.prefix(5))) else { return raw ?? "" }
    return time.formatted24h
}
