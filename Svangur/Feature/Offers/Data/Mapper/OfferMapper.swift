import Foundation

// JUDGMENT CALL: `Offer.customDiscountText` is overloaded on the read path to also carry the
// server's pre-formatted discount label (`discount_label_en` on detail, `discount_label` on
// list) when present. Android's real `OfferDraft.customDiscountText` is strictly "free text the
// owner typed when discount_value == custom", but the reshaped iOS `Offer` (per the task spec)
// has no separate field for a server-rendered display label, and reusing this slot lets
// `discountDisplayText` (`Presentation/Mapper/OfferUiMapper.swift`) show the server's own
// formatting without inventing a new domain field. This only matters for READ mappings below;
// `OfferDraft.toMultipartFields` (repository) only ever sends `customDiscountText` back to the
// server when `discountId == "custom"`, matching Android's real write-path semantics exactly.

extension OwnerOfferDetailDTO {
    func toDomain() -> Offer {
        let sortedImages = images.sorted { $0.sortOrder < $1.sortOrder }
        let mappedImageUrls = sortedImages.compactMap { URL(string: $0.url) }
        let heroURL = imageUrl.flatMap { URL(string: $0) } ?? mappedImageUrls.first

        return Offer(
            id: offerId,
            restaurantId: nil,
            titleEn: titleEn,
            titleIs: (titleIs?.isEmpty == false) ? titleIs! : titleEn,
            descriptionEn: descriptionEn,
            descriptionIs: descriptionIs,
            categoryId: category?.id,
            discountValue: discountValue,
            customDiscountText: (discountLabelEn?.isEmpty == false) ? discountLabelEn : nil,
            validDays: Set(validDays.compactMap { Weekday(dayCode: $0) }),
            validTimeStart: validTimeStart.flatMap { TimeOfDay(string: $0) } ?? .startOfDay,
            validTimeEnd: validTimeEnd.flatMap { TimeOfDay(string: $0) } ?? .endOfDay,
            status: status.flatMap { OfferStatus(rawValue: $0) },
            isActive: status == "active",
            heroImageUrl: heroURL,
            imageUrls: mappedImageUrls,
            imageIds: sortedImages.map { String($0.id) },
            views: stats?.views ?? 0,
            clicks: stats?.clicks ?? 0
        )
    }
}

extension OwnerOfferListItemDTO {
    func toDomain() -> Offer {
        // The list DTO has no `sort_order` field — images are used exactly as listed.
        let mappedImageUrls = images.compactMap { URL(string: $0.url) }
        let heroURL = imageUrl.flatMap { URL(string: $0) } ?? mappedImageUrls.first

        return Offer(
            id: offerId,
            restaurantId: nil,
            titleEn: title,
            // The list endpoint has no separate `title_is` — fall back to the single wire value.
            titleIs: title,
            descriptionEn: description,
            descriptionIs: nil,
            // The list endpoint has no `category_id` at all — only the detail endpoint does.
            categoryId: nil,
            // The list endpoint has no raw `discount_value` — only a pre-formatted label.
            discountValue: nil,
            customDiscountText: (discountLabel?.isEmpty == false) ? discountLabel : nil,
            validDays: Set(validDays.compactMap { Weekday(dayCode: $0) }),
            validTimeStart: validTimeStart.flatMap { TimeOfDay(string: $0) } ?? .startOfDay,
            validTimeEnd: validTimeEnd.flatMap { TimeOfDay(string: $0) } ?? .endOfDay,
            status: status.flatMap { OfferStatus(rawValue: $0) },
            isActive: status == "active",
            heroImageUrl: heroURL,
            imageUrls: mappedImageUrls,
            imageIds: images.map { String($0.id) },
            views: 0,
            clicks: 0
        )
    }
}

extension OfferAnalyticsDTO {
    func toDomain() -> OfferAnalytics {
        OfferAnalytics(
            views: views,
            viewsChangePct: viewsChangePct,
            clicks: clicks,
            clicksChangePct: clicksChangePct,
            mapActions: mapActions,
            mapActionsChangePct: mapActionsChangePct,
            callActions: callActions,
            callActionsChangePct: callActionsChangePct,
            websiteActions: websiteActions,
            websiteActionsChangePct: websiteActionsChangePct,
            period: period
        )
    }
}
