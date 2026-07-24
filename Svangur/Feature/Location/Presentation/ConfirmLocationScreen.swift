import SwiftUI
import MapKit

struct ConfirmLocationScreen: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @StateObject var viewModel: ConfirmLocationViewModel

    init(viewModel: ConfirmLocationViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }

    @ViewBuilder
    private func compactLayout() -> some View {
        ZStack {
            // The map is created only AFTER the target coordinate is resolved — its initial
            // camera is set at creation time, so the first rendered frame is already centered
            // on the right location instead of flashing a default and jumping.
            if viewModel.isReady {
                mapLayer
                pinMarker
                    .allowsHitTesting(false)
                bottomCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            } else {
                detectingLocationPlaceholder
            }
            topHeader
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isReady)
        .ignoresSafeArea(edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.onAppear()
        }
    }

    // MARK: - Pre-map placeholder (while the current location is being resolved)

    private var detectingLocationPlaceholder: some View {
        VStack(spacing: SvSpacing.md) {
            ProgressView()
                .tint(Color.svPrimary)
            Text("Detecting location…")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.svBackground)
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Detecting location")
    }

    // MARK: - Map
    //
    // `MapCameraPosition` (used by the iOS 17+ `Map(position:)` initializer) is itself an
    // iOS-17-only type — even declaring a `@State private var: MapCameraPosition` on a struct
    // that must compile unconditionally at an iOS 16 deployment target is a build error,
    // regardless of any `#available` runtime guard around its *usage*. So the two Map variants
    // are split into separate child View types below: `ModernMapLayer` is itself annotated
    // `@available(iOS 17, *)` (its `MapCameraPosition` property is then valid), and
    // `LegacyMapLayer` is the iOS 16-safe fallback using the legacy `Map(coordinateRegion:)` API.
    // Both react to `viewModel.latitude`/`longitude` changing (e.g. once `onAppear()` resolves a
    // real place) by recentering themselves.

    @ViewBuilder
    private var mapLayer: some View {
        if #available(iOS 17, *) {
            ModernMapLayer(viewModel: viewModel)
        } else {
            // iOS 16 fallback — no `.mapStyle`/`.onMapCameraChange` equivalent; a custom
            // `Binding` forwards every region change (drag/zoom) to `viewModel.updateCoordinate`,
            // preserving the "confirm location by dragging the map" behavior.
            LegacyMapLayer(viewModel: viewModel)
        }
    }

    // MARK: - Center pin marker (fixed at screen center — the SELECTED location)
    //
    // Deliberately NOT the blue "current location" dot: that comes from the map itself
    // (`UserAnnotation()` / `showsUserLocation`) and stays pinned to the device's real GPS
    // position while this pin tracks whatever the map is centered on.

    private var pinMarker: some View {
        Image(systemName: "mappin")
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(.black)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            // Lifts the pin so its tip — not its middle — sits on the map's center point.
            .offset(y: -15)
    }

    // MARK: - Top header

    private var topHeader: some View {
        HStack(spacing: SvSpacing.md) {
            Button {
                router.pop()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
            }
            .accessibilityLabel("Back")

            Text("Confirm Location")
                .font(SvFont.title)
                .foregroundStyle(Color.svOnBackground)

            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.md)
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            Text("Showing deals for")
                .font(.system(size: 18, weight: .semibold))
              //  .foregroundStyle(Color.black.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 22,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 22
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.06),
                                Color.white.opacity(0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
            HStack(spacing: SvSpacing.sm) {
                Image("pinIcon")
                    .frame(width: 15, height: 24)
                    .foregroundStyle(Color.svOnBackground)
                Text(viewModel.name)
                    .font(SvFont.title)
                    .foregroundStyle(Color.svOnBackground)
            }

            Text(viewModel.address)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            SvPrimaryButton(title: "Confirm Location") {
                Task {
                    await viewModel.confirmLocation()
                    router.popToRoot()
                }
            }
            .padding(.top, SvSpacing.xs)
        }
        .padding(SvSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                .fill(Color.svOnPrimary)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.bottom, SvSpacing.xxl)
    }
}

// MARK: - Map layer variants

@available(iOS 17, *)
private struct ModernMapLayer: View {
    @ObservedObject var viewModel: ConfirmLocationViewModel
    @State private var cameraPosition: MapCameraPosition

    init(viewModel: ConfirmLocationViewModel) {
        self.viewModel = viewModel
        self._cameraPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: viewModel.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
        ))
    }

    var body: some View {
        // `.all` interaction modes: pan, pinch/double-tap/two-finger zoom, rotate, and pitch.
        // `UserAnnotation()` renders the system blue dot at the device's real GPS position —
        // it moves only when the GPS fix changes, never with map drags.
        Map(position: $cameraPosition, interactionModes: .all) {
            UserAnnotation()
        }
            .mapStyle(.standard(elevation: .flat))
            .onMapCameraChange(frequency: .continuous) { context in
                viewModel.updateCoordinate(
                    latitude: context.region.center.latitude,
                    longitude: context.region.center.longitude
                )
            }
            // No programmatic recenter observers: this layer is only created once the target
            // coordinate is resolved, so the initial camera (set in `init`) is already right —
            // and any camera write after creation would fight the user's pan/zoom gestures.
            .ignoresSafeArea()
    }
}

private struct LegacyMapLayer: View {
    @ObservedObject var viewModel: ConfirmLocationViewModel
    @State private var region: MKCoordinateRegion

    init(viewModel: ConfirmLocationViewModel) {
        self.viewModel = viewModel
        self._region = State(initialValue: MKCoordinateRegion(
            center: viewModel.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    var body: some View {
        // `showsUserLocation` renders the system blue dot at the real GPS position,
        // independent of the draggable selection pin at screen center. No programmatic
        // recenter: this layer is only created once the target coordinate is resolved (see
        // `ModernMapLayer`), so the initial region is already right.
        Map(coordinateRegion: regionBinding, interactionModes: .all, showsUserLocation: true)
            .ignoresSafeArea()
    }

    private var regionBinding: Binding<MKCoordinateRegion> {
        Binding(
            get: { region },
            set: { newRegion in
                region = newRegion
                viewModel.updateCoordinate(
                    latitude: newRegion.center.latitude,
                    longitude: newRegion.center.longitude
                )
            }
        )
    }
}

// MARK: - Previews

#Preview("Confirm Location - Default") {
    NavigationStack {
        ConfirmLocationScreen(viewModel: .previewInstance())
    }
    .environmentObject(AppRouter())
}

#Preview("Confirm Location - Current") {
    NavigationStack {
        ConfirmLocationScreen(viewModel: .previewInstance(name: "Current location"))
    }
    .environmentObject(AppRouter())
}
