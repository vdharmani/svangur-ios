import Foundation

/// Domain-layer search result (equivalent to Android's `SearchResult`).
/// Named `SearchOffer` on iOS to avoid clashing with the existing
/// Presentation-layer `SearchResultUi` model.
struct SearchOffer: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let offer: String
    let badge: String
    let distanceKm: String
    let validDays: String
    let imageUrl: String?
}
