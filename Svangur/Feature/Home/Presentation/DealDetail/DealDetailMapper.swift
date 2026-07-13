import Foundation

extension Offer {
    func toDealDetail() -> DealDetailUi {
        let sortedDays = validDays.sorted()
        let dayNames = sortedDays.map { $0.shortName }

        let mockRestaurants = [
            "Bella Italia", "Pizza Palace", "The Golden Fork",
            "Burger Joint", "Sweet Bites"
        ]
        let mockCategories = ["Italian", "American", "European", "Mexican", "Japanese"]
        let idx = Int(id - 1) % mockRestaurants.count

        return DealDetailUi(
            id: id,
            restaurantName: mockRestaurants[idx],
            categoryLabel: mockCategories[idx],
            discountBadge: discountDisplayText,
            description: descriptionEn ?? "",
            validDays: dayNames,
            validTimeText: "\(validTimeStart.formatted24h)\u{2013}\(validTimeEnd.formatted24h)",
            heroImageName: "SampleOfferPizza",
            photoImageNames: ["SampleOfferPizza", "SampleOfferBurgers", "SampleFoodThumb"]
        )
    }
}
