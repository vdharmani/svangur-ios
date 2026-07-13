import Foundation

struct DealMapPin: Identifiable, Equatable, Sendable {
    let id: Int64
    let latitude: Double
    let longitude: Double
    let restaurantName: String
    let title: String
    let discountBadge: String
    let categoryImageName: String
    let validTimeText: String
    let distance: String
}

extension DealMapPin {
    static let mockPins: [DealMapPin] = [
        DealMapPin(
            id: 1,
            latitude: 40.7148,
            longitude: -74.0068,
            restaurantName: "Bello Italio",
            title: "20% off sushi platters",
            discountBadge: "20%",
            categoryImageName: "SampleOfferPizza",
            validTimeText: "Tue – Fri 17:00 – 21:00",
            distance: "1.2 km"
        ),
        DealMapPin(
            id: 2,
            latitude: 40.7165,
            longitude: -74.0030,
            restaurantName: "Burger Barn",
            title: "2-for-1 burgers",
            discountBadge: "2-for-1",
            categoryImageName: "SampleOfferBurgers",
            validTimeText: "Mon – Thu 11:30 – 14:00",
            distance: "0.8 km"
        ),
        DealMapPin(
            id: 3,
            latitude: 40.7120,
            longitude: -74.0045,
            restaurantName: "Pizza Palace",
            title: "30% off all pizzas",
            discountBadge: "30%",
            categoryImageName: "SampleOfferPizza",
            validTimeText: "Wed 11:00 – 22:00",
            distance: "2.1 km"
        ),
        DealMapPin(
            id: 4,
            latitude: 40.7138,
            longitude: -74.0010,
            restaurantName: "Masti Shakes",
            title: "Free dessert with main",
            discountBadge: "Free",
            categoryImageName: "SampleFoodThumb",
            validTimeText: "Fri – Sat 18:00 – 22:00",
            distance: "1.5 km"
        ),
        DealMapPin(
            id: 5,
            latitude: 40.7108,
            longitude: -74.0080,
            restaurantName: "Noodle House",
            title: "25% off ramen bowls",
            discountBadge: "25%",
            categoryImageName: "SampleFoodThumb",
            validTimeText: "Every day 12:00 – 15:00",
            distance: "3.0 km"
        ),
    ]
}
