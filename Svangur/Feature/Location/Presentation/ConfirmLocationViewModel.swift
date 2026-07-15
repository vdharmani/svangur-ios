import SwiftUI
import Combine
import CoreLocation

@MainActor
final class ConfirmLocationViewModel: ObservableObject {
    let name: String
    @Published private(set) var address: String
    @Published private(set) var latitude: Double
    @Published private(set) var longitude: Double

    private let placesService: PlacesServiceProtocol
    private let selectedLocationStore: SelectedLocationStoreProtocol
    /// The Google Places `place_id` the user picked on the search screen — `nil` for a recent
    /// search chip or "Use current location", which carry no Places suggestion to look up.
    private let placeID: String?

    init(
        placesService: PlacesServiceProtocol,
        selectedLocationStore: SelectedLocationStoreProtocol,
        name: String,
        placeID: String?
    ) {
        self.placesService = placesService
        self.selectedLocationStore = selectedLocationStore
        self.name = name
        self.placeID = placeID
        // Placeholder until `onAppear()` resolves the real place (or forever, if `placeID` is
        // `nil` — e.g. a recent search chip with no coordinate attached yet).
        self.address = "Phase 8B, Sector 74, Sahibzada Ajit Singh Nagar, Punjab, India. (F-267)"
        self.latitude = 30.7046
        self.longitude = 76.7179
    }

    /// Resolves the real address/coordinate for the picked Places suggestion. Triggered by the
    /// View's `.task { }` rather than `init`, per this project's no-side-effects-in-init rule.
    func onAppear() async {
        guard let placeID else { return }
        guard let details = try? await placesService.placeDetails(placeID: placeID) else { return }
        if let formattedAddress = details.formattedAddress { address = formattedAddress }
        latitude = details.latitude
        longitude = details.longitude
    }

    func updateCoordinate(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
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
        ConfirmLocationViewModel(
            placesService: FakePlacesService(),
            selectedLocationStore: FakeSelectedLocationStore(),
            name: name,
            placeID: nil
        )
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
