import Foundation

struct SearchResultUi: Equatable, Identifiable, Sendable {
    let id: Int64
    let restaurantName: String
    let dealTitle: String
    let distanceAndTime: String
    let imageUrl: URL?
}
