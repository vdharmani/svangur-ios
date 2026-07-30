import Foundation

struct DealMapPin: Identifiable, Equatable, Sendable {
    let id: Int64
    let latitude: Double
    let longitude: Double
    let restaurantName: String
    let title: String
    /// Number of active offers this pin's restaurant has — drives the marker's subtitle
    /// ("1 Deal" / "N Deals"). Computed across the whole pins feed in `toMapPins()`.
    let dealCount: Int
    let discountBadge: String
    let imageUrl: URL?
    let validTimeText: String
    let distance: String
    /// Whether the restaurant is open right now — drives the map popup's "Open now" badge.
    let isOpenNow: Bool
}

extension DealMapPin {
    static let mockPins: [DealMapPin] = [
        DealMapPin(
            id: 1,
            latitude: 40.7148,
            longitude: -74.0068,
            restaurantName: "Bello Italio",
            title: "20% off sushi platters",
            dealCount: 2,
            discountBadge: "20%",
            imageUrl: nil,
            validTimeText: "Tue – Fri 17:00 – 21:00",
            distance: "1.2 km",
            isOpenNow: true
        ),
        DealMapPin(
            id: 2,
            latitude: 40.7165,
            longitude: -74.0030,
            restaurantName: "Burger Barn",
            title: "2-for-1 burgers",
            dealCount: 1,
            discountBadge: "2-for-1",
            imageUrl: nil,
            validTimeText: "Mon – Thu 11:30 – 14:00",
            distance: "0.8 km",
            isOpenNow: true
        ),
        DealMapPin(
            id: 3,
            latitude: 40.7120,
            longitude: -74.0045,
            restaurantName: "Pizza Palace",
            title: "30% off all pizzas",
            dealCount: 3,
            discountBadge: "30%",
            imageUrl: nil,
            validTimeText: "Wed 11:00 – 22:00",
            distance: "2.1 km",
            isOpenNow: true
        ),
        DealMapPin(
            id: 4,
            latitude: 40.7138,
            longitude: -74.0010,
            restaurantName: "Masti Shakes",
            title: "Free dessert with main",
            dealCount: 1,
            discountBadge: "Free",
            imageUrl: nil,
            validTimeText: "Fri – Sat 18:00 – 22:00",
            distance: "1.5 km",
            isOpenNow: false
        ),
        DealMapPin(
            id: 5,
            latitude: 40.7108,
            longitude: -74.0080,
            restaurantName: "Noodle House",
            title: "25% off ramen bowls",
            dealCount: 1,
            discountBadge: "25%",
            imageUrl: nil,
            validTimeText: "Every day 12:00 – 15:00",
            distance: "3.0 km",
            isOpenNow: true
        ),
    ]
}
