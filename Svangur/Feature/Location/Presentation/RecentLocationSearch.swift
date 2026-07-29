import Foundation

/// A location the user previously searched for and picked. Carries `placeID` (not just the
/// display text) so re-selecting it from the recent-searches list resolves the same real
/// coordinate/address again via `PlacesServiceProtocol.placeDetails(placeID:)` — without it,
/// `ConfirmLocationViewModel` has nothing to look up and falls back to the device's GPS fix.
struct RecentLocationSearch: Codable, Equatable, Identifiable, Sendable {
    let displayName: String
    let placeID: String?

    var id: String { displayName }

    /// A short "locality, region" label for the Recent Searches chips — trims the street-level
    /// prefix (when present) and the trailing country segment (when a more specific state/region
    /// segment exists), instead of showing the full comma-separated `displayName` Google's Places
    /// Autocomplete returns (e.g. "1600 Amphitheatre Parkway, Mountain View, CA, USA").
    /// `displayName` itself is left untouched — it's still what's stored/deduped and what's
    /// passed to `ConfirmLocationViewModel`, only this derived label is shortened for display.
    var shortDisplayName: String {
        let parts = displayName
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Already short (a bare locality, or "locality, country") — nothing to trim.
        guard parts.count > 2 else {
            return parts.isEmpty ? displayName : parts.joined(separator: ", ")
        }

        // For "…, locality, region, country", drop everything before `locality` and the
        // trailing `country`, keeping just "locality, region".
        let locality = parts[parts.count - 3]
        let region = parts[parts.count - 2]
        return "\(locality), \(region)"
    }
}
