import Foundation

struct OfferAnalyticsUi: Equatable, Sendable {
    let views: Int
    let viewsChangePct: Int
    let clicks: Int
    let clicksChangePct: Int
    /// Human-readable comparison period, e.g. "week" for "vs last week". Derived from
    /// `OfferAnalytics.period`'s raw wire value (`"last_7_days"`, etc.) — see `OfferUiMapper`.
    let periodLabel: String
}
