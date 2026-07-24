import SwiftUI
import Combine
import CoreLocation

@MainActor
final class ConfirmLocationViewModel: ObservableObject {
    let name: String
    @Published private(set) var address: String
    @Published private(set) var latitude: Double
    @Published private(set) var longitude: Double
    /// False until `onAppear()` resolves the target coordinate (Places details or GPS fix).
    /// The screen holds the map back behind a "Detecting location…" placeholder until then,
    /// so the map's very first frame is already centered on the right location — no flash of
    /// a default coordinate followed by a jump.
    @Published private(set) var isReady = false

    /// `nonisolated(unsafe)`: only ever mutated from `@MainActor` methods, except for the
    /// `cancel()` call in `deinit` — see `RegisterRestaurantViewModel.addressSearchTask` for
    /// the same pattern and rationale.
    nonisolated(unsafe) private var geocodeTask: Task<Void, Never>?
    /// Last coordinate an address was resolved for — guards against redundant reverse
    /// geocodes when the camera settles without actually moving (e.g. after a programmatic
    /// recenter re-reports the same center).
    private var lastGeocodedCoordinate: CLLocationCoordinate2D?

    private let placesService: PlacesServiceProtocol
    private let selectedLocationStore: SelectedLocationStoreProtocol
    private let locationService: LocationServiceProtocol
    /// The Google Places `place_id` the user picked — from a search result or a recent-search
    /// chip (recents store the ID of the originally picked result, so re-selecting one shows
    /// the SAME place again). `nil` only for "Use current location" (or a legacy recent saved
    /// without an ID); `onAppear()` then resolves the pin from the device's GPS fix instead,
    /// so the screen opens with the pin aligned on the blue current-location dot.
    private let placeID: String?

    init(
        placesService: PlacesServiceProtocol,
        selectedLocationStore: SelectedLocationStoreProtocol,
        locationService: LocationServiceProtocol,
        name: String,
        placeID: String?
    ) {
        self.placesService = placesService
        self.selectedLocationStore = selectedLocationStore
        self.locationService = locationService
        self.name = name
        self.placeID = placeID
        // Placeholder until `onAppear()` resolves the real place (or forever, if `placeID` is
        // `nil` — e.g. a recent search chip with no coordinate attached yet).
        self.address = "Phase 8B, Sector 74, Sahibzada Ajit Singh Nagar, Punjab, India. (F-267)"
        self.latitude = 30.7046
        self.longitude = 76.7179
    }

    deinit {
        geocodeTask?.cancel()
    }

    /// Resolves the real address/coordinate — from the picked Places suggestion, or from the
    /// device's GPS fix for "Use current location". Triggered by the View's `.task { }` rather
    /// than `init`, per this project's no-side-effects-in-init rule.
    func onAppear() async {
        // `.task` fires again when navigating back to this screen — the coordinate is already
        // resolved then, so don't re-resolve (and re-flash the placeholder) on re-appear.
        guard !isReady else { return }
        // Even if resolution fails (denied permission, no GPS fix, offline), the screen must
        // eventually show the map rather than sit on the placeholder forever.
        defer { isReady = true }

        if let placeID {
            let details = try? await placesService.placeDetails(placeID: placeID)
            // Reset only AFTER the details fetch completes (success or failure) — it must reuse
            // the same session token the autocomplete search used, so Google bills the
            // autocomplete + details pair as one session; resetting any earlier would
            // invalidate that token before this call fires.
            await placesService.resetSession()
            guard let details else { return }
            if let formattedAddress = details.formattedAddress { address = formattedAddress }
            latitude = details.latitude
            longitude = details.longitude
        } else {
            // No Places suggestion to look up ("Use current location" or a recent chip) —
            // open centered on the device's GPS fix, pin aligned on the blue dot.
            guard let coordinate = try? await locationService.currentLocation() else { return }
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            if let placemark = try? await locationService.reverseGeocode(coordinate),
               let resolvedAddress = placemark.address {
                address = resolvedAddress
            }
        }
        // The address above is authoritative for this coordinate — don't let the map's
        // settle-geocode immediately overwrite it with a re-lookup of the same point.
        lastGeocodedCoordinate = coordinate
    }

    /// Fed continuously from the map's camera while the user pans/zooms — keeps the selected
    /// coordinate on the screen-center pin, and schedules a reverse geocode that resolves the
    /// displayed address once the camera stops moving.
    func updateCoordinate(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
        scheduleReverseGeocode()
    }

    /// Debounced: each camera movement resets the timer, so the geocode fires only once the
    /// map has been still for a moment ("after the user stops moving the map").
    private func scheduleReverseGeocode() {
        geocodeTask?.cancel()
        geocodeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.reverseGeocodeCenter()
        }
    }

    private func reverseGeocodeCenter() async {
        let center = coordinate
        // Zoom-only changes and programmatic recenters re-report the same center — skip.
        if let last = lastGeocodedCoordinate,
           abs(last.latitude - center.latitude) < 0.000_01,
           abs(last.longitude - center.longitude) < 0.000_01 {
            return
        }
        guard let placemark = try? await locationService.reverseGeocode(center) else { return }
        guard !Task.isCancelled else { return }
        lastGeocodedCoordinate = center
        if let resolvedAddress = placemark.address {
            address = resolvedAddress
        }
    }

    /// Publishes the pin's final resting position to `HomeViewModel` — triggered by the View's
    /// "Confirm Location" button, right before `router.popToRoot()`.
    func confirmLocation() async {
        await selectedLocationStore.set(
            SelectedLocation(latitude: latitude, longitude: longitude, displayText: name)
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Preview Factory

extension ConfirmLocationViewModel {
    @MainActor
    static func previewInstance(name: String = "Industrial Area") -> ConfirmLocationViewModel {
        let vm = ConfirmLocationViewModel(
            placesService: FakePlacesService(),
            selectedLocationStore: FakeSelectedLocationStore(),
            locationService: FakeLocationService(),
            name: name,
            placeID: nil
        )
        vm.isReady = true
        return vm
    }
}

private struct FakeLocationService: LocationServiceProtocol {
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus { .authorizedWhenInUse }
    func currentLocation() async throws(AppError) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 64.1466, longitude: -21.9426)
    }
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws(AppError) -> PlacemarkInfo {
        PlacemarkInfo(address: "Laugavegur 1", city: "Reykjavik", country: "Iceland")
    }
}

private actor FakeSelectedLocationStore: SelectedLocationStoreProtocol {
    func set(_ location: SelectedLocation) {}
    func updates() -> AsyncStream<SelectedLocation> { AsyncStream { _ in } }
}

private struct FakePlacesService: PlacesServiceProtocol {
    func autocomplete(query: String) async throws(AppError) -> [PlaceSuggestion] {
        [PlaceSuggestion(id: "1", description: "\(query), Reykjavik, Iceland")]
    }
    func placeDetails(placeID: String) async throws(AppError) -> PlaceDetails {
        PlaceDetails(
            formattedAddress: "Laugavegur 1, 101 Reykjavik, Iceland",
            city: "Reykjavik",
            country: "Iceland",
            latitude: 64.1466,
            longitude: -21.9426
        )
    }
    func resetSession() async {}
}
