import Foundation

/// Mirrors Android's real backend review-workflow states for an owner offer.
/// NOTE: the raw values are the literal wire strings sent by `/owner/offers*` — there is no
/// `.active` case here; "is this offer currently active" is a *separate* signal
/// (`Offer.isActive`, derived from the raw `status` string equalling `"active"`), matching
/// Android's `OfferRepositoryImpl` which computes `isActive = (status == "active")`
/// independently of parsing into this closed enum.
enum OfferStatus: String, Sendable, Equatable, CaseIterable {
    case pendingApproval = "pending_approval"
    case approved
    case rejected
    case revisionRequested = "revision_requested"
    case expired
}
