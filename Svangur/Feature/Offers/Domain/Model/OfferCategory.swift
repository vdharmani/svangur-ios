import Foundation

/// JUDGMENT CALL (reshape to real backend API): `Offer.category` no longer exists — the real
/// backend uses a dynamic `categoryId: Int64?` referencing the owner-category list fetched via
/// `DealRepositoryProtocol.listOwnerCategories()` (see `Feature/Deals/Domain/Model/DealCategory`).
///
/// This fixed, closed-set enum is kept ONLY because `Feature/Home`'s "Food Categories" filter
/// row (`HomeScreen.categoryItem`) is a hardcoded, purely-local set of chips with bundled
/// artwork (burger/pizza/sushi icons) that has no reliable mapping to the backend's dynamic
/// category IDs. Threading the real category list into Home's filter chips (with real icons,
/// real IDs) is a bigger redesign explicitly out of scope for this "minimal rewire" pass — see
/// `HomeViewModel.applyFilters()` for the accepted limitation (category selection no longer
/// filters results; it only drives chip highlighting).
///
/// This type is NOT used by `Offer`, `OfferDraft`, or any Data-layer DTO/mapper anymore.
enum OfferCategory: String, Sendable, Equatable, CaseIterable, Identifiable {
    case pizza
    case burgers
    case sushi
    case kebab
    case asian
    case mexican
    case indian
    case vegetarian
    case dessert
    case drinks
    case other

    var id: String { rawValue }

    var displayNameKey: String {
        "offer_category_\(rawValue)"
    }
}
