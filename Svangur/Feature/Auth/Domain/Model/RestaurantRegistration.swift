import Foundation

struct HourMinute: Sendable, Equatable, Hashable {
    let hour: Int
    let minute: Int

    static let nineAM = HourMinute(hour: 9, minute: 0)
    static let tenPM  = HourMinute(hour: 22, minute: 0)

    var formattedString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

struct DaySchedule: Sendable, Equatable, Hashable {
    var isOpen: Bool
    var openTime: HourMinute
    var closeTime: HourMinute

    static let standardOpen = DaySchedule(isOpen: true,  openTime: .nineAM, closeTime: .tenPM)
    static let closed       = DaySchedule(isOpen: false, openTime: .nineAM, closeTime: .tenPM)
}

struct RestaurantRegistration: Sendable, Equatable {
    let restaurantName: String
    var restaurantNameIcelandic: String = ""
    let email: String
    let password: String
    let phoneNumber: String
    let description: String
    var descriptionIcelandic: String = ""
    let imageRefs: [URL]
    let documentRef: URL?
    let openingHours: [Weekday: DaySchedule]
    // No static fallback for any of these — the registration screen now derives address/city/
    // country/latitude/longitude from the device's actual current location.
    var address: String = ""
    var city: String = ""
    var country: String = ""
    var latitude: Double?
    var longitude: Double?
    var website: String?
}
