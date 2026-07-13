/// Full details for a single selected Places autocomplete suggestion — city/country/coordinate
/// tied to the exact place the user picked, rather than the device's current GPS location.
struct PlaceDetails: Sendable, Equatable {
    let formattedAddress: String?
    let city: String?
    let country: String?
    let latitude: Double
    let longitude: Double
}
