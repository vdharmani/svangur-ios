import Foundation

extension Offer {
    /// `titleEn`/`descriptionEn` fall back for `.icelandic` when the owner never filled in an
    /// Icelandic translation — `titleIs`/`descriptionIs` are non-optional-but-possibly-empty on
    /// the wire (`OfferRepositoryImpl.buildMultipart` mirrors this: it submits the English value
    /// under `title_is` too when the Icelandic field was left blank), so an empty string here
    /// means "untranslated," not "translated to nothing."
    /// - Parameters:
    ///   - categories: real owner categories (`DealRepositoryProtocol.listOwnerCategories`), used
    ///     to resolve `categoryId` to a display name. Pass `[]` (the default) when the caller
    ///     hasn't fetched them — falls back to the `"Category #N"` placeholder.
    ///   - restaurantProfile: the owner's restaurant profile, used for the phone/website contact
    ///     chips and the map-pin location. Pass `nil` (the default) when not fetched/available.
    ///   - analytics: per-offer view/click stats. Pass `nil` (the default) to hide the stats cards.
    func toUi(
        for language: AppLanguage,
        categories: [DealCategory] = [],
        restaurantProfile: RestaurantEditData? = nil,
        analytics: OfferAnalytics? = nil
    ) -> OfferUi {
        let title = (language == .icelandic && !titleIs.isEmpty) ? titleIs : titleEn
        let description: String
        switch language {
        case .icelandic:
            description = (descriptionIs?.isEmpty == false) ? descriptionIs! : (descriptionEn ?? "")
        case .english:
            description = descriptionEn ?? ""
        }

        let categoryName = categoryId
            .flatMap { id in categories.first { $0.id == String(id) } }?
            .localizedName(for: language)

        // Same "fall back to English when the Icelandic field is blank" rule as the offer's own
        // title/description above — `RestaurantEditData.nameIs`/`nameEn` are non-optional-but-
        // possibly-empty on the wire, same as `titleIs`.
        let restaurantName: String? = restaurantProfile.map { profile in
            (language == .icelandic && !profile.nameIs.isEmpty) ? profile.nameIs : profile.nameEn
        }

        return OfferUi(
            id: id,
            title: title,
            description: description,
            categoryDisplayText: categoryName ?? Self.categoryDisplayText(for: categoryId),
            discountBadgeText: discountDisplayText,
            validDaysText: Self.formatValidDays(validDays),
            validDayNames: validDays.sorted().map(Self.dayShortName),
            validTimeText: "\(validTimeStart.formatted24h)–\(validTimeEnd.formatted24h)",
            imageUrls: imageUrls,
            status: status,
            isActive: isActive,
            restaurantName: restaurantName,
            restaurantPhone: restaurantProfile?.phoneNumber.isEmpty == false ? restaurantProfile?.phoneNumber : nil,
            restaurantWebsite: restaurantProfile?.website.isEmpty == false ? restaurantProfile?.website : nil,
            latitude: restaurantProfile?.latitude,
            longitude: restaurantProfile?.longitude,
            analytics: analytics?.toUi()
        )
    }

    /// JUDGMENT CALL: falls back to a generic placeholder using the raw ID when the real
    /// `[DealCategory]` list wasn't supplied (fetch failed/empty) or has no matching entry.
    /// Uses `String(localized:)` (not a plain literal) because this runs in the mapper, outside
    /// any SwiftUI `Text` — plain `String` values never go through the String Catalog on their
    /// own, so this was previously stuck in English even when the app language was Icelandic.
    nonisolated private static func categoryDisplayText(for categoryId: Int64?) -> String {
        guard let categoryId else { return String(localized: "Uncategorized") }
        return String(localized: "Category #\(categoryId)")
    }

    nonisolated private static func formatValidDays(_ days: Set<Weekday>) -> String {
        if days.count == 7 { return String(localized: "Every day") }
        if days.isEmpty { return "—" }
        return days.sorted().map(Self.dayShortName).joined(separator: ", ")
    }

    nonisolated private static func dayShortName(_ day: Weekday) -> String {
        switch day {
        case .monday:    return String(localized: "Mon")
        case .tuesday:   return String(localized: "Tue")
        case .wednesday: return String(localized: "Wed")
        case .thursday:  return String(localized: "Thu")
        case .friday:    return String(localized: "Fri")
        case .saturday:  return String(localized: "Sat")
        case .sunday:    return String(localized: "Sun")
        }
    }
}

extension OfferAnalytics {
    func toUi() -> OfferAnalyticsUi {
        OfferAnalyticsUi(
            views: views,
            viewsChangePct: viewsChangePct,
            clicks: clicks,
            clicksChangePct: clicksChangePct,
            periodLabel: Self.periodLabel(for: period)
        )
    }

    /// The wire `period` is a raw bucket key, not display text — this renders it as
    /// "vs last <periodLabel>" in the stats cards. The real API returns compound keys like
    /// `"last_7_days_vs_prev_7_days"` (verified against `GET /owner/offers/{id}/analytics`),
    /// not just the bare `"last_7_days"` used by `MockOfferRepository` — naively replacing every
    /// underscore with a space on that compound form produced a doubled "vs last last 7 days vs
    /// prev 7 days". Strip the `"_vs_prev..."` suffix (and a leading "last_") first so only the
    /// window size (e.g. "7 days") remains, THEN fall back to the simple bucket names / generic
    /// underscore-replace for anything else.
    nonisolated private static func periodLabel(for period: String) -> String {
        if let vsRange = period.range(of: "_vs_prev") {
            let window = period[period.startIndex..<vsRange.lowerBound]
                .replacingOccurrences(of: "^last_", with: "", options: .regularExpression)
                .replacingOccurrences(of: "_", with: " ")
            return window.isEmpty ? "period" : window
        }
        switch period {
        case "last_7_days":  return "week"
        case "last_30_days": return "month"
        case "last_24_hours", "today": return "day"
        default: return period.replacingOccurrences(of: "_", with: " ")
        }
    }
}

/// JUDGMENT CALL: the backend has no discriminated discount type anymore — just a raw
/// `discount_value` string (see `Offer.discountValue`) plus an optional pre-rendered/custom
/// label (`Offer.customDiscountText`, overloaded on the read path — see `OfferMapper.swift`).
/// This formatter is intentionally approximate: prefer the label if the server/user supplied
/// one, special-case the "bogo" sentinel used by `AddOfferScreen`'s discount picker, and
/// otherwise assume the raw value is a percentage. Good enough for display; NOT a source of
/// truth for what the value actually means.
extension Offer {
    var discountDisplayText: String {
        if let customDiscountText, !customDiscountText.isEmpty {
            return customDiscountText
        }
        if let discountValue {
            if discountValue == "bogo" { return String(localized: "Buy 1 Get 1") }
            return String(localized: "\(discountValue)% off")
        }
        return String(localized: "Special offer")
    }
}
