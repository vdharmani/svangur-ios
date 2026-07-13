import Foundation

struct OfferUi: Equatable, Identifiable, Sendable {
    let id: Int64
    let title: String
    let description: String
    let categoryDisplayText: String
    let discountBadgeText: String
    let validDaysText: String
    let validDayNames: [String]
    let validTimeText: String
    let imageUrls: [URL]
    let status: OfferStatus?
    let isActive: Bool
}
