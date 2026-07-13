import SwiftUI
import CoreLocation

@MainActor
@Observable
final class ConfirmLocationViewModel {
    let name: String
    private(set) var address: String
    private(set) var latitude: Double
    private(set) var longitude: Double

    init(name: String) {
        self.name = name
        // Placeholder address + coordinate. Wire reverse geocoding via
        // CLGeocoder and update on `updateCoordinate(_:_:)` when the
        // backend supports it.
        self.address = "Phase 8B, Sector 74, Sahibzada Ajit Singh Nagar, Punjab, India. (F-267)"
        self.latitude = 30.7046
        self.longitude = 76.7179
    }

    func updateCoordinate(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Preview Factory

extension ConfirmLocationViewModel {
    @MainActor
    static func previewInstance(name: String = "Industrial Area") -> ConfirmLocationViewModel {
        ConfirmLocationViewModel(name: name)
    }
}
