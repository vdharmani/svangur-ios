import Foundation

struct DealDetailUi: Equatable, Sendable, Identifiable {
    let id: Int64
    let restaurantName: String
    let categoryLabel: String
    let discountBadge: String
    let description: String
    let validDays: [String]
    let validTimeText: String
    let heroImageUrl: URL?
    let photoImageUrls: [URL]
    let latitude: Double?
    let longitude: Double?
    let phone: String?
}
