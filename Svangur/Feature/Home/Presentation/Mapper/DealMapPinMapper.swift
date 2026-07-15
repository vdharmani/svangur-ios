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
            categoryImageName: mapPinCategoryImageName(for: categoryName),
            validTimeText: "\(dealCardTime(validTimeStart))–\(dealCardTime(validTimeEnd))",
            distance: distanceKm.map { String(format: "%.1f km", $0) } ?? ""
        )
    }
}

/// JUDGMENT CALL: same bundled-photography limitation as `HomeScreen.categoryIconAssets(for:)` —
/// only a handful of categories have real bundled art; any other category name falls back to a
/// generic thumbnail so newly added backend categories still render a pin.
private func mapPinCategoryImageName(for categoryName: String?) -> String {
    switch categoryName?.lowercased() {
    case let name? where name.contains("burger"): return "SampleOfferBurgers"
    case let name? where name.contains("pizza"): return "SampleOfferPizza"
    default: return "SampleFoodThumb"
    }
}
