import Foundation

extension Offer {
    func toUi() -> OfferUi {
        OfferUi(
            id: id,
            title: titleEn,
            description: descriptionEn ?? "",
            categoryDisplayText: Self.categoryDisplayText(for: categoryId),
            discountBadgeText: discountDisplayText,
            validDaysText: Self.formatValidDays(validDays),
            validDayNames: validDays.sorted().map(Self.dayShortName),
            validTimeText: "\(validTimeStart.formatted24h)–\(validTimeEnd.formatted24h)",
            imageUrls: imageUrls,
            status: status,
            isActive: isActive
        )
    }

    /// JUDGMENT CALL: `Dashboard`/`OfferDetail` don't fetch the real `[DealCategory]` list (only
    /// `AddOfferViewModel` does, for the edit form's picker) — threading it through every
    /// read-only screen just to display a category name was judged too invasive for this
    /// "minimal rewire" pass. Falls back to a generic placeholder using the raw ID.
    nonisolated private static func categoryDisplayText(for categoryId: Int64?) -> String {
        guard let categoryId else { return "Uncategorized" }
        return "Category #\(categoryId)"
    }

    nonisolated private static func formatValidDays(_ days: Set<Weekday>) -> String {
        if days.count == 7 { return "Every day" }
        if days.isEmpty { return "—" }
        return days.sorted().map(Self.dayShortName).joined(separator: ", ")
    }

    nonisolated private static func dayShortName(_ day: Weekday) -> String {
        switch day {
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        case .sunday:    return "Sun"
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
            if discountValue == "bogo" { return "Buy 1 Get 1" }
            return "\(discountValue)% off"
        }
        return "Special offer"
    }
}
