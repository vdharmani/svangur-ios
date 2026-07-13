import Foundation

enum DiscountFilter: String, Sendable, Equatable, CaseIterable, Identifiable {
    case all
    case twentyPlus
    case thirtyPlus
    case twoForOne

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:        return "All Offers"
        case .twentyPlus: return "20%+"
        case .thirtyPlus: return "30%+"
        case .twoForOne:  return "2 for 1"
        }
    }

    var iconName: String? {
        switch self {
        case .all: return "flame.fill"
        default:   return nil
        }
    }

    /// JUDGMENT CALL (reshape to real backend API): the backend has no discriminated discount
    /// type — `Offer.discountValue` is a raw string (a percentage number, `"bogo"`, `"custom"`,
    /// etc; see `AddOfferScreen`'s discount picker). This matches against that raw string
    /// directly instead of the old `OfferDiscount` enum's cases.
    func matches(_ discountValue: String?) -> Bool {
        switch self {
        case .all:
            return true
        case .twentyPlus:
            guard let discountValue, let value = Int(discountValue) else { return false }
            return value >= 20
        case .thirtyPlus:
            guard let discountValue, let value = Int(discountValue) else { return false }
            return value >= 30
        case .twoForOne:
            return discountValue == "bogo"
        }
    }
}
