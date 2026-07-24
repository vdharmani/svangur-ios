import CoreLocation
import Foundation

protocol GetCurrentLocationUseCaseProtocol: Sendable {
    func execute() async throws(AppError) -> LocationSnapshot
}

/// An `actor` (rather than a plain stateless class) so the resolved `LocationSnapshot` can be
/// cached and overlapping callers de-duped onto a single in-flight fetch. `DIContainer` hands out
/// ONE shared instance app-wide, so the fetch kicked off at launch (`RootView`'s splash
/// `onFinished`, in parallel with the splash animation and session bootstrap) is the very same
/// fetch `HomeViewModel.onAppear` consumes — Home gets the cached result instantly, or at worst
/// awaits whatever's left of the already-in-flight GPS fix + reverse-geocode, instead of starting
/// a brand new permission-check → GPS fix → reverse-geocode round trip once the user is already
/// looking at the screen.
actor GetCurrentLocationUseCase: GetCurrentLocationUseCaseProtocol {
    private let locationService: LocationServiceProtocol
    private var cached: LocationSnapshot?
    private var inFlight: Task<LocationSnapshot, Error>?

    init(locationService: LocationServiceProtocol) {
        self.locationService = locationService
    }

    func execute() async throws(AppError) -> LocationSnapshot {
        if let cached { return cached }

        let task: Task<LocationSnapshot, Error>
        if let inFlight {
            task = inFlight
        } else {
            let service = locationService
            task = Task { try await Self.fetch(using: service) }
            inFlight = task
        }

        do {
            let snapshot = try await apiCall { try await task.value }
            cached = snapshot
            inFlight = nil
            return snapshot
        } catch {
            inFlight = nil
            throw error
        }
    }

    private static func fetch(using locationService: LocationServiceProtocol) async throws -> LocationSnapshot {
        let coordinate = try await locationService.currentLocation()
        let placemark = try await locationService.reverseGeocode(coordinate)

        let displayText: String
        switch (placemark.city, placemark.country) {
        case let (city?, country?): displayText = "\(city), \(country)"
        case let (city?, nil):      displayText = city
        case let (nil, country?):   displayText = country
        case (nil, nil):
            throw AppError.unknown(message: "Couldn't determine a location name.")
        }

        return LocationSnapshot(latitude: coordinate.latitude, longitude: coordinate.longitude, displayText: displayText)
    }
}
