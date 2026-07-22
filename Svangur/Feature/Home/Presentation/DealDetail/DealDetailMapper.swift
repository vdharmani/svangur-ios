import Foundation

extension DealListing {
    func toDealDetail() -> DealDetailUi {
        let dayNames = validDays
            .sorted()
            .compactMap { Weekday(rawValue: $0 + 1)?.shortName }

        return DealDetailUi(
            id: Int64(id) ?? 0,
            restaurantName: restaurantName ?? "",
            categoryLabel: categoryName ?? "",
            discountBadge: customDiscountText ?? "",
            description: description ?? "",
            validDays: dayNames,
            validTimeText: "\(dealCardTime(validTimeStart))\u{2013}\(dealCardTime(validTimeEnd))",
            heroImageUrl: heroImageUrl.flatMap(URL.init(string:)),
            photoImageUrls: imageUrls.compactMap(URL.init(string:)),
            latitude: latitude,
            longitude: longitude,
            phone: phone
        )
    }
}
