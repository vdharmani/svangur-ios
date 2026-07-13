import Foundation

/// Mirrors Android's `OfferAnalytics` — per-offer stats returned by
/// `GET /owner/offers/{id}/analytics`. Each metric is paired with a `_changePct` — the
/// percentage change versus the prior comparison period (see `period`).
struct OfferAnalytics: Sendable, Equatable {
    let views: Int
    let viewsChangePct: Int
    let clicks: Int
    let clicksChangePct: Int
    let mapActions: Int
    let mapActionsChangePct: Int
    let callActions: Int
    let callActionsChangePct: Int
    let websiteActions: Int
    let websiteActionsChangePct: Int
    let period: String
}
