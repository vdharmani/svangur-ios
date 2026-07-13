import Foundation

struct DealCardUi: Equatable, Identifiable, Sendable {
    let id: Int64
    let restaurantName: String
    let title: String
    let discountBadge: String
    let categoryName: String
    let distance: String
    let validTimeText: String
    let imageUrl: URL?
    let isOpenNow: Bool
}
