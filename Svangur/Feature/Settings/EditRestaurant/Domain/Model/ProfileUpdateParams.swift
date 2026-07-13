import Foundation

struct ProfileUpdateParams: Sendable, Equatable {
    let nameEn: String
    let nameIs: String
    let phone: String
    let descriptionEn: String
    let descriptionIs: String
    let address: String
    let city: String
    let country: String
    let latitude: Double?
    let longitude: Double?
    let website: String?
    let openingHours: [OpeningHourParam]
    let imageUris: [String]
}
