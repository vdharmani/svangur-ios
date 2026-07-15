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
            mapLayer
            pinMarker
                .allowsHitTesting(false)
            topHeader
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            bottomCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.onAppear()
        }
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

    // MARK: - Center pin marker (fixed at screen center)

    private var pinMarker: some View {
        ZStack {
            Circle()
                .fill(Color.svConfirmAccuracy)
                .frame(width: 70, height: 70)

            Circle()
                .fill(Color.svConfirmDot)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

            Image(systemName: "mappin")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.black)
                .offset(y: -28)
        }
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
                router.popToRoot()
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
        Map(position: $cameraPosition)
            .mapStyle(.standard(elevation: .flat))
            .onMapCameraChange { context in
                viewModel.updateCoordinate(
                    latitude: context.region.center.latitude,
                    longitude: context.region.center.longitude
                )
            }
            // Recenters once `viewModel.onAppear()` resolves a real place (async, after this
            // view is first created with the placeholder coordinate).
            .onChange(of: viewModel.latitude) { _, _ in
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: viewModel.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                )
            }
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
        Map(coordinateRegion: regionBinding)
            // Recenters once `viewModel.onAppear()` resolves a real place. Uses the iOS
            // 14-compatible single-argument `.onChange(of:perform:)` overload since this view
            // has no `@available` guard.
            .onChange(of: viewModel.latitude) { _ in
                region = MKCoordinateRegion(
                    center: viewModel.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            }
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

// Local map-marker tokens — promote to Color.svMapPin* in the Asset Catalog
// when the design system adds a map palette.
private extension Color {
    static let svConfirmDot      = Color(red: 0.20, green: 0.47, blue: 0.96)
    static let svConfirmAccuracy = Color(red: 0.20, green: 0.47, blue: 0.96).opacity(0.18)
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
