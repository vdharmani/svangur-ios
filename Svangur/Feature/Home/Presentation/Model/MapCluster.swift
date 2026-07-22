import MapKit

/// One or more nearby `DealMapPin`s grouped together for map display. `pins.count == 1`
/// renders as a normal pin; anything larger renders as a numbered cluster bubble.
struct MapCluster: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let pins: [DealMapPin]

    var count: Int { pins.count }

    static func == (lhs: MapCluster, rhs: MapCluster) -> Bool {
        lhs.id == rhs.id && lhs.pins == rhs.pins
    }
}

extension MapCluster {
    /// Greedy distance-based clustering: pins within `region`'s current zoom-relative
    /// threshold collapse into one cluster centered on their average coordinate. The
    /// threshold scales with `region.span`, so pins merge more aggressively when zoomed
    /// out and separate back into individual pins as the user zooms in.
    /// Below this span (roughly a 3km-wide viewport), clustering turns off entirely —
    /// zooming in this close always shows individual pins, regardless of how close together
    /// the underlying restaurants happen to be. A single "merge if within X% of span" rule
    /// can't satisfy both "cluster when zoomed out" and "always split apart once I'm zoomed
    /// in close", since real pin spacing varies — this explicit cutoff makes the zoomed-in
    /// case deterministic instead of depending on how far apart nearby restaurants happen to be.
    private static let clusteringDisabledBelowSpan: CLLocationDegrees = 0.03

    static func clustering(_ pins: [DealMapPin], region: MKCoordinateRegion) -> [MapCluster] {
        guard region.span.latitudeDelta >= clusteringDisabledBelowSpan else {
            return pins.map { pin in
                MapCluster(
                    id: "cluster-\(pin.id)",
                    coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                    pins: [pin]
                )
            }
        }

        // Tuning knob: fraction of the visible span two pins can be apart and still merge.
        // 0.06 was too tight — even zoomed all the way out it only merged pins within ~80m,
        // so real-world restaurant spacing never actually clustered. 0.2 merges pins within
        // roughly a fifth of the visible map, which noticeably consolidates on zoom-out while
        // still splitting back into individual pins as the user zooms in.
        let latThreshold = region.span.latitudeDelta * 0.2
        let lngThreshold = region.span.longitudeDelta * 0.2

        var clusters: [MapCluster] = []

        for pin in pins {
            if let index = clusters.firstIndex(where: { cluster in
                abs(cluster.coordinate.latitude - pin.latitude) < latThreshold &&
                abs(cluster.coordinate.longitude - pin.longitude) < lngThreshold
            }) {
                let mergedPins = clusters[index].pins + [pin]
                let avgLatitude = mergedPins.map(\.latitude).reduce(0, +) / Double(mergedPins.count)
                let avgLongitude = mergedPins.map(\.longitude).reduce(0, +) / Double(mergedPins.count)
                clusters[index] = MapCluster(
                    id: clusters[index].id,
                    coordinate: CLLocationCoordinate2D(latitude: avgLatitude, longitude: avgLongitude),
                    pins: mergedPins
                )
            } else {
                clusters.append(MapCluster(
                    id: "cluster-\(pin.id)",
                    coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                    pins: [pin]
                ))
            }
        }

        return clusters
    }
}
