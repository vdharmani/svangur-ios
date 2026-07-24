import Foundation

/// Mirrors Android's real add/edit form draft (`OfferDraft.kt`) — NOT the same shape as
/// `Offer`. Images are deliberately split into three groups, matching Android exactly:
/// - `imageUris`: NEW local files staged for multipart upload.
/// - `existingImageUrls` / `existingImageIds`: server-side images already attached to the
///   offer (display-only; parallel arrays, same index refers to the same image).
/// - `removedImageIds`: existing image IDs the user removed in this editing session — sent
///   as `remove_image_ids` on update.
struct OfferDraft: Sendable, Equatable {
    var offerId: Int64?
    var title: String
    var titleIs: String
    var description: String
    var descriptionIs: String
    var categoryId: Int64?
    /// Becomes the wire `discount_value` field verbatim (e.g. a percentage string, `"bogo"`,
    /// or `"custom"`).
    var discountId: String?
    var customDiscountText: String?
    var validDays: Set<Weekday>
    /// `nil` until the user picks a time — the field is mandatory, so `ValidateOfferDraftUseCase`
    /// treats either being unset as invalid rather than silently defaulting to a placeholder time.
    var validTimeStart: TimeOfDay?
    var validTimeEnd: TimeOfDay?
    var imageUris: [URL]
    var existingImageUrls: [URL]
    var existingImageIds: [String]
    var removedImageIds: [String]

    nonisolated static let empty = OfferDraft(
        offerId: nil,
        title: "",
        titleIs: "",
        description: "",
        descriptionIs: "",
        categoryId: nil,
        discountId: nil,
        customDiscountText: nil,
        validDays: [],
        validTimeStart: nil,
        validTimeEnd: nil,
        imageUris: [],
        existingImageUrls: [],
        existingImageIds: [],
        removedImageIds: []
    )
}

extension OfferDraft {
    init(from offer: Offer) {
        self.init(
            offerId: offer.id,
            title: offer.titleEn,
            titleIs: offer.titleIs,
            description: offer.descriptionEn ?? "",
            descriptionIs: offer.descriptionIs ?? "",
            categoryId: offer.categoryId,
            discountId: offer.discountValue,
            customDiscountText: offer.customDiscountText,
            validDays: offer.validDays,
            validTimeStart: offer.validTimeStart,
            validTimeEnd: offer.validTimeEnd,
            imageUris: [],
            existingImageUrls: offer.imageUrls,
            existingImageIds: offer.imageIds,
            removedImageIds: []
        )
    }
}
