import Foundation

struct RestaurantEditData: Sendable, Equatable {
    let nameEn: String
    let nameIs: String
    let adminEmail: String
    let phoneNumber: String
    let descriptionEn: String
    let descriptionIs: String
    let address: String
    let city: String
    let country: String
    let latitude: Double?
    let longitude: Double?
    let website: String
    let openingHours: [EditDaySchedule]
    let restaurantImages: [String]

    init(
        nameEn: String,
        nameIs: String,
        adminEmail: String,
        phoneNumber: String,
        descriptionEn: String,
        descriptionIs: String,
        address: String,
        city: String,
        country: String,
        latitude: Double?,
        longitude: Double?,
        website: String,
        openingHours: [EditDaySchedule],
        restaurantImages: [String] = []
    ) {
        self.nameEn = nameEn
        self.nameIs = nameIs
        self.adminEmail = adminEmail
        self.phoneNumber = phoneNumber
        self.descriptionEn = descriptionEn
        self.descriptionIs = descriptionIs
        self.address = address
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.website = website
        self.openingHours = openingHours
        self.restaurantImages = restaurantImages
    }
}
