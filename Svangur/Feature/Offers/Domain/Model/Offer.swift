import Foundation

/// Mirrors Android's real `OfferSummary` / owner-offer detail shape (`/owner/offers*`).
/// Deliberately dual-language (`titleEn`/`titleIs`) instead of a single `title` — the
/// backend has no combined field. `categoryId` references the dynamic category list
/// fetched via `DealRepositoryProtocol.listOwnerCategories()` (Feature/Deals), NOT a
/// closed local enum. `discountValue` is a raw server string (percentage, "bogo", "custom",
/// etc.) — NOT a discriminated `OfferDiscount` enum; use `discountDisplayText` (in
/// `OfferUiMapper`) for a human-readable label.
///
/// `createdAt`/`updatedAt` are intentionally NOT modeled: Android's list DTO never provides
/// them, and the detail DTO's `created_at` is optional and unused by any Offers screen today.
struct Offer: Sendable, Equatable, Identifiable {
    let id: Int64
    let restaurantId: Int64?
    let titleEn: String
    let titleIs: String
    let descriptionEn: String?
    let descriptionIs: String?
    let categoryId: Int64?
    let discountValue: String?
    let customDiscountText: String?
    let validDays: Set<Weekday>
    let validTimeStart: TimeOfDay
    let validTimeEnd: TimeOfDay
    let status: OfferStatus?
    /// Derived from the raw wire `status == "active"` — independent of the `OfferStatus`
    /// enum above, matching Android's `OfferRepositoryImpl` mapping exactly.
    let isActive: Bool
    let heroImageUrl: URL?
    let imageUrls: [URL]
    let imageIds: [String]
    let views: Int
    let clicks: Int
}
