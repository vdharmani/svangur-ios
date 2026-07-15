import Foundation

/// Wire-format weekday codes used by the Deal API, in Monday-first order.
/// Mirrors Android's `DealRepositoryImpl.DAY_CODES`.
private let dealDayCodes = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

private func mapValidDays(_ codes: [String]) -> [Int] {
    codes.map { dealDayCodes.firstIndex(of: $0) ?? -1 }.filter { $0 >= 0 }
}

extension FeedItemDTO {
    func toDomain() -> DealListing {
        DealListing(
            id: String(offerId),
            restaurantId: restaurant?.id.map { String($0) },
            restaurantName: restaurant?.name,
            categoryId: nil,
            categoryName: nil,
            title: title,
            description: description,
            discountType: nil,
            discountPercent: nil,
            customDiscountText: discountLabel,
            validTimeStart: validTimeStart,
            validTimeEnd: validTimeEnd,
            validDays: mapValidDays(validDays),
            heroImageUrl: imageUrl,
            imageUrls: images.map(\.url),
            address: restaurant?.address,
            latitude: restaurant?.latitude,
            longitude: restaurant?.longitude,
            distanceKm: restaurant?.distanceKm,
            isOpenNow: restaurant?.isOpenNow,
            opensAt: restaurant?.opensAt,
            rating: nil,
            views: stats?.views ?? 0,
            clicks: stats?.clicks ?? 0
        )
    }
}

extension OfferDetailDTO {
    func toDomain() -> DealListing {
        let sortedImages = images.sorted { $0.sortOrder < $1.sortOrder }

        return DealListing(
            id: String(offerId),
            restaurantId: restaurant?.id.map { String($0) },
            restaurantName: restaurant?.name,
            categoryId: category?.id.map { String($0) },
            categoryName: category?.name,
            title: title,
            description: description,
            discountType: nil,
            discountPercent: nil,
            customDiscountText: discountLabel,
            validTimeStart: validTimeStart,
            validTimeEnd: validTimeEnd,
            validDays: mapValidDays(validDays),
            heroImageUrl: sortedImages.first?.url,
            imageUrls: sortedImages.map(\.url),
            address: restaurant?.location?.address,
            latitude: restaurant?.location?.lat,
            longitude: restaurant?.location?.lng,
            distanceKm: restaurant?.distanceKm,
            isOpenNow: restaurant?.isOpenNow,
            rating: nil,
            phone: restaurant?.phone,
            website: restaurant?.website,
            views: stats?.views ?? 0,
            clicks: stats?.clicks ?? 0
        )
    }
}

extension DealCategoryFilterDTO {
    func toDomain() -> DealCategory {
        DealCategory(
            id: String(id),
            slug: "",
            nameEn: label,
            nameIs: label,
            sortOrder: 0
        )
    }
}

extension DiscountUserFilterDTO {
    func toDomain() -> DiscountUserFilter {
        DiscountUserFilter(id: id, key: key, label: label)
    }
}

extension DiscountOwnerOptionDTO {
    func toDomain() -> DiscountOwnerOption {
        DiscountOwnerOption(id: id, value: value, kind: kind, label: label)
    }
}
