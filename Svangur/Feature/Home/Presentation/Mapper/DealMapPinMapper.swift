import Foundation

extension DealListing {
    /// `nil` when the deal has no coordinate — a pin can't be placed on the map without one.
    func toMapPin() -> DealMapPin? {
        guard let latitude, let longitude else { return nil }
        return DealMapPin(
            id: Int64(id) ?? 0,
            latitude: latitude,
            longitude: longitude,
            restaurantName: restaurantName ?? "",
            title: title,
            discountBadge: customDiscountText ?? "",
            imageUrl: heroImageUrl.flatMap(URL.init(string:)),
            validTimeText: "\(dealCardTime(validTimeStart))–\(dealCardTime(validTimeEnd))",
            distance: distanceKm.map { String(format: "%.1f km", $0) } ?? ""
        )
    }
}
