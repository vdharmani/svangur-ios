import Foundation

extension DealListing {
    /// `nil` when the deal has no coordinate — a pin can't be placed on the map without one.
    /// `dealCount` is how many offers this listing's restaurant has in the pins feed — only
    /// computable across the whole feed, so `toMapPins()` below supplies it.
    func toMapPin(dealCount: Int = 1) -> DealMapPin? {
        guard let latitude, let longitude else { return nil }
        return DealMapPin(
            id: Int64(id) ?? 0,
            latitude: latitude,
            longitude: longitude,
            restaurantName: restaurantName ?? "",
            title: title,
            dealCount: dealCount,
            discountBadge: customDiscountText ?? "",
            imageUrl: heroImageUrl.flatMap(URL.init(string:)),
            validTimeText: "\(dealCardTime(validTimeStart))–\(dealCardTime(validTimeEnd))",
            distance: distanceKm.map { String(format: "%.1f km", $0) } ?? "",
            isOpenNow: isOpenNow ?? false
        )
    }
}

extension Array where Element == DealListing {
    /// Maps the pins feed to `DealMapPin`s, stamping each pin with how many offers its
    /// restaurant has across the whole feed (the marker subtitle's "N Deals" count).
    /// Listings without a `restaurantId` can't be grouped, so they count as 1.
    func toMapPins() -> [DealMapPin] {
        let dealCountByRestaurantId = Dictionary(grouping: compactMap(\.restaurantId), by: { $0 })
            .mapValues(\.count)
        return compactMap { listing in
            listing.toMapPin(
                dealCount: listing.restaurantId.flatMap { dealCountByRestaurantId[$0] } ?? 1
            )
        }
    }
}
