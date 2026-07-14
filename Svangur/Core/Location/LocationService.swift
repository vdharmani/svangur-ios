import Foundation
import CoreLocation

/// A reverse-geocoded street address, city, and country — any field may be `nil` if Apple's
/// geocoder didn't return it for that coordinate.
struct PlacemarkInfo: Sendable, Equatable {
    let address: String?
    let city: String?
    let country: String?
}

protocol LocationServiceProtocol: Sendable {
    /// Prompts the system permission dialog if not yet determined; returns immediately with
    /// the current status otherwise. Never call this from `init` — trigger it from user intent
    /// (e.g. a screen's `.task { }`), per this project's location-permission rules.
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus
    /// One-shot current location fetch (`CLLocationManager.requestLocation()`), not a
    /// continuous stream — exactly what's needed for a single lat/lng capture.
    func currentLocation() async throws(AppError) -> CLLocationCoordinate2D
    /// Reverse-geocodes a coordinate into a human-readable address/city/country.
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws(AppError) -> PlacemarkInfo
}

actor LocationService: LocationServiceProtocol {
    private let manager: CLLocationManager
    private let delegate: LocationDelegateProxy

    init() {
        let proxy = LocationDelegateProxy()
        self.delegate = proxy
        self.manager = CLLocationManager()
        self.manager.delegate = proxy
    }

    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        let current = manager.authorizationStatus
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            delegate.authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentLocation() async throws(AppError) -> CLLocationCoordinate2D {
        let status = await requestWhenInUseAuthorization()
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw .unknown(message: "Location permission was denied.")
        }
        do {
            let location: CLLocation = try await withCheckedThrowingContinuation { continuation in
                delegate.locationContinuation = continuation
                manager.requestLocation()
            }
            return location.coordinate
        } catch {
            throw error.toAppError()
        }
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws(AppError) -> PlacemarkInfo {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            // `CLGeocoder`'s completion-handler API is bridged to `async throws` automatically.
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                throw AppError.unknown(message: "Couldn't find an address for this location.")
            }
            let streetParts = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }
            return PlacemarkInfo(
                address: streetParts.isEmpty ? nil : streetParts.joined(separator: " "),
                city: placemark.locality,
                country: placemark.country
            )
        } catch {
            throw error.toAppError()
        }
    }
}

/// `CLLocationManagerDelegate` requires an `NSObject`-based conformer, which an `actor` cannot
/// be — this thin proxy bridges delegate callbacks into `CheckedContinuation`s for `LocationService`.
/// `@unchecked Sendable`: callbacks arrive serialized on the manager's delegate queue, and every
/// continuation is set immediately before the single call that triggers it (from within the
/// actor, which itself serializes access) — there's no concurrent read/write of the same field.
private final class LocationDelegateProxy: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    var locationContinuation: CheckedContinuation<CLLocation, Error>?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationContinuation?.resume(returning: manager.authorizationStatus)
        authorizationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }
}
