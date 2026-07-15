import CoreLocation
import Foundation

protocol GetCurrentLocationUseCaseProtocol: Sendable {
    func execute() async throws(AppError) -> LocationSnapshot
}

final class GetCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol, Sendable {
    private let locationService: LocationServiceProtocol

    init(locationService: LocationServiceProtocol) {
        self.locationService = locationService
    }

    func execute() async throws(AppError) -> LocationSnapshot {
        let coordinate = try await locationService.currentLocation()
        let placemark = try await locationService.reverseGeocode(coordinate)

        let displayText: String
        switch (placemark.city, placemark.country) {
        case let (city?, country?): displayText = "\(city), \(country)"
        case let (city?, nil):      displayText = city
        case let (nil, country?):   displayText = country
        case (nil, nil):
            throw .unknown(message: "Couldn't determine a location name.")
        }

        return LocationSnapshot(latitude: coordinate.latitude, longitude: coordinate.longitude, displayText: displayText)
    }
}
