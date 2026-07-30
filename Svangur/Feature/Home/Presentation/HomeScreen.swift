import SwiftUI
import MapKit
import os

// TEMPORARY — investigating why the map's deal popup doesn't open for some markers.
// Remove this logging once the root cause is confirmed and fixed.
private extension Logger {
    static let map = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Svangur", category: "map")
}

struct HomeScreen: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: UserSession
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @StateObject var viewModel: HomeViewModel
    // Reykjavik — used only until `viewModel.currentLocation` resolves (or if it never does).
    private static let fallbackMapCoordinate = CLLocationCoordinate2D(latitude: 64.1466, longitude: -21.9426)
    private static let mapSpan = MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)

    // Single source of truth for the map's center — `MKCoordinateRegion` is available pre-iOS 17,
    // unlike `MapCameraPosition` (iOS 17+ only), so it can't be a stored property's type here.
    // The iOS 17+ `Map(position:)` binding below wraps/unwraps this region on the fly instead.
    // The fallback seed is INERT: the map itself isn't rendered until a real location resolves
    // (see `mapContent`'s gate), so this coordinate is never visible to the user.
    @State private var mapRegion = MKCoordinateRegion(
        center: HomeScreen.fallbackMapCoordinate,
        span: HomeScreen.mapSpan
    )

    // Set the first time the map centers on a REAL location (GPS fix or manually confirmed).
    // Once true, re-appearing (e.g. returning from Deal Details) never re-centers — `mapRegion`
    // keeps whatever pan/zoom the user last had. Only an actual location *change* (via
    // `onChange(of: viewModel.currentLocation)`) moves the map after this point.
    @State private var hasCenteredMapOnUserLocation = false

    // Measured *height* of the currently-rendered deal popup card, used to anchor it above the
    // selected marker (see `popupAnchor(for:mapSize:cardHeight:)`). Seeded with the card's
    // approximate rendered height so the very first popup placement (before the real measurement
    // lands via `MapDealCardHeightPreferenceKey`) is already close, instead of momentarily
    // sitting on top of the marker. Width is NOT measured — see `mapDealCardWidth` below for why.
    @State private var mapDealCardHeight: CGFloat = 160

    private static let mapMarkerWidth: CGFloat = 44
    private static let mapMarkerHeight = mapMarkerWidth * (200.0 / 167.0)

    // Per the popup design: the card spans the map width minus a fixed 24pt margin on each
    // side (`screenPadding`), capped at 520pt so it doesn't stretch edge-to-edge on iPad.
    // On iPhone the horizontal clamp in `popupAnchor` therefore collapses to (near) center —
    // the card sits centered while still tracking the marker vertically.
    private static let mapDealCardMaxWidth: CGFloat = 520
    private static let mapDealCardHorizontalMargin: CGFloat = SvSpacing.screenPadding

    // SwiftUI's `.onTapGesture` on `Map` also fires for taps that an annotation `Button` already
    // handled — annotation content lives in MapKit-managed (UIKit-hosted) layers, so SwiftUI's
    // gesture arbitration doesn't treat the button as consuming the touch. That pass-through
    // duplicate arrives within the same event cycle (~1 frame), dismissing the popup right after
    // `selectPin(pin)` opened it. Every annotation tap stamps this deadline; the empty-map tap
    // handler ignores taps arriving before it. The window is deliberately short — a real
    // "tap marker, then tap empty area to dismiss" sequence takes far longer than 200ms.
    @State private var suppressEmptyMapTapUntil = Date.distantPast
    private static let emptyMapTapSuppressionWindow: TimeInterval = 0.2

    init(viewModel: HomeViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }

    // MARK: - Layout
    private func compactLayout() -> some View {
        VStack(spacing: 2) {
            headerSection
            if viewModel.viewMode == .list {
                listContent
            } else {
                mapContent
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.svBackground)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .svErrorBanner(viewModel.refreshErrorMessage)
        .task { await viewModel.onAppear(lang: languageService.current.rawValue) }
        // `.task { }` above only fires once per view identity — toggling the flag mid-session
        // needs this separate hook so server-driven content (days, categories, discount
        // filters, deals) re-fetches in the new language instead of staying stuck.
        .onChange(of: languageService.current) { newValue in
            Task { await viewModel.onLanguageChange(lang: newValue.rawValue) }
        }
    }

    private var listContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                categoriesSection
                    .padding(.bottom, SvSpacing.xl)
                discountSection
                    .padding(.bottom, SvSpacing.xl)
                // `daysSection`'s horizontal ScrollView already carries 6pt of vertical padding
                // internally (so the day chips' drop shadow isn't clipped at the scroll edges) —
                // subtract it here so the visible gap before "All Deals" matches every other
                // section gap instead of reading larger.
                daysSection
                    .padding(.bottom, SvSpacing.xl - 6)
                dealsSection
            }
            .padding(.top, SvSpacing.xxl)
            .padding(.bottom, SvSpacing.xxxl)
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Header

    private var headerSection: some View {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    Button {
                        router.navigate(to: .selectLocation)
                    } label: {
                        VStack(alignment: .leading, spacing: SvSpacing.xs) {
                            HStack(spacing: SvSpacing.sm) {
                                Image("ic_location")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                Text("Home")
                                    .font(SvFont.title)
                                    .foregroundStyle(Color.svOnPrimary)
                                Image("downArrow")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.svOnPrimary.opacity(0.8))
                            }
                            Text(viewModel.locationDisplayText)
                                .font(SvFont.caption)
                                .foregroundStyle(Color.svOnPrimary)
                                .padding(.leading, SvSpacing.xxs)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change location")
                    
                    Spacer()
                    HStack(spacing: SvSpacing.md) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                languageService.toggle()
                            }
                        } label: {
                            HStack(spacing: SvSpacing.xs) {
                                SvLanguageFlagIcon(language: languageService.current)
                                    .frame(width: 19, height: 12)
                                Text(languageService.current.displayLabel)
                                    .font(SvFont.captionStrong)
                                    .foregroundStyle(Color.svOnPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Switch language")
                        .accessibilityValue(languageService.current == .english ? "English" : "Icelandic")

                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                viewModel.toggleViewMode()
                            }
                        } label: {
                            Image("ic_Svlocation")
                                .frame(width: 30, height: 30)
                        }
                        Button {
                            if session.isAuthenticated {
                                router.navigate(to: .dashboard)
                            } else {
                                router.navigate(to: .entry)
                            }
                        } label: {
                            Image("ic_home")
                                .frame(width: 30, height: 30)
                        }
                    }
                    .padding(.top, SvSpacing.xs)
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, viewModel.viewMode == .list ? SvSpacing.lg : SvSpacing.lg)
                if viewModel.viewMode == .list {
                    searchBar
                        .padding(.horizontal, SvSpacing.screenPadding)
                        .padding(.top, SvSpacing.lg)
                        .padding(.bottom, SvSpacing.xxxl)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    Spacer().frame(height: SvSpacing.lg)
                }
            }
            .padding(.top, SvSpacing.xxxl)
            .background(
                LinearGradient(
                    colors: [Color.svPrimaryGradientStart, Color.svPrimaryGradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: viewModel.viewMode == .list ? 40 : 0,
                    bottomTrailingRadius: viewModel.viewMode == .list ? 40 : 0
                )
            )
        }

    private var searchBar: some View {
        Button {
            router.navigate(to: .search)
        } label: {
            HStack(spacing: SvSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.svSecondary)

                Text("Search restaurant")
                    .font(SvFont.bodySmall)
                    .foregroundStyle(Color.svSecondary)

                Spacer()
            }
            .padding(.horizontal, SvSpacing.lg)
            .frame(height: SvSpacing.inputHeight)
            .background(
                RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                    .fill(Color.svPink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                    .stroke(Color.svDivider, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
                                                      
    // MARK: - Map View

    /// Gates the real map behind location resolution: until a real location exists (GPS or a
    /// manually confirmed one via `ConfirmLocationScreen`), the map area shows a loading
    /// placeholder — never a map centered on the mock/fallback coordinate, and therefore no
    /// markers or popups positioned around a fake location. Once the map has centered on a
    /// real location once (`hasCenteredMapOnUserLocation`), it stays mounted regardless.
    @ViewBuilder
    private var mapContent: some View {
        if viewModel.currentLocation == nil && !hasCenteredMapOnUserLocation {
            mapLocationPendingView
        } else {
            activeMapContent
        }
    }

    /// Skeleton state per the UX rules (shimmer, not a bare centered spinner) shown while
    /// location permission is pending or the fix is still being resolved.
    private var mapLocationPendingView: some View {
        ZStack {
            Rectangle()
                .fill(Color.svShimmer)
                .svShimmer()
            Text("Detecting location…")
                .font(SvFont.caption)
                .foregroundStyle(Color.svSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
    }

    private var activeMapContent: some View {
        let clusters = MapCluster.clustering(viewModel.mapPins, region: mapRegion)

        // Wrapped in `GeometryReader` (rather than measuring the `Map` itself) so the popup's
        // anchor math has a stable pixel size to convert map coordinates against — see
        // `screenPoint(for:in:)` / `popupAnchor(for:mapSize:cardSize:)` below. The reader itself
        // (not just the `Map` inside it) ignores the bottom safe area so `geo.size` matches the
        // `Map`'s actual rendered bounds exactly, keeping the anchor math accurate all the way
        // to the bottom edge.
        let baseMap = GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Group {
                    if #available(iOS 17, *) {
                        // `MapCameraPosition` is iOS 17+ only, so it can't back a stored property on
                        // this pre-iOS-17-deployment-target screen — this binding wraps/unwraps it
                        // around `mapRegion` (the actual `@State`) on the fly, only inside this branch.
                        Map(position: Binding<MapCameraPosition>(
                            get: { .region(mapRegion) },
                            set: { newPosition in
                                if let region = newPosition.region {
                                    mapRegion = region
                                }
                            }
                        )) {
                            // The system blue current-location dot — standard indicator, not a
                            // custom marker. Renders only once Core Location has a fix (which
                            // is guaranteed here, since the map itself is gated on location).
                            UserAnnotation()

                            ForEach(clusters) { cluster in
                                Annotation(clusterLabel(cluster), coordinate: cluster.coordinate) {
                                    mapAnnotationView(cluster)
                                }
                            }
                        }
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                        }
                        // The position binding's `set` above only fires when `newPosition.region`
                        // is non-nil, but `MapCameraPosition` frequently represents live user
                        // interaction (pinch/pan) in a form where `.region` is nil — silently
                        // dropping the update and leaving `mapRegion` (and clustering, which reads
                        // its span) stuck at the initial value forever. `onMapCameraChange` reports
                        // the actual region reliably on every camera change instead. This also
                        // drives the popup anchor, so it keeps tracking its marker live while
                        // panning/zooming.
                        .onMapCameraChange { context in
                            mapRegion = context.region
                        }
                    } else {
                        // iOS 16 fallback — the legacy `Map(coordinateRegion:...)` initializer has no
                        // equivalent for `.mapControls` (compass / user-location button), so those are
                        // simply omitted here. Pin rendering + selection behavior is unchanged.
                        Map(
                            coordinateRegion: $mapRegion,
                            interactionModes: .all,
                            showsUserLocation: true,   // System blue dot — iOS 16 equivalent of `UserAnnotation()`
                            annotationItems: clusters
                        ) { cluster in
                            MapAnnotation(coordinate: cluster.coordinate) {
                                mapAnnotationView(cluster)
                            }
                        }
                    }
                }
                // Deselects the pin and dismisses the popup on empty-map taps, same as tapping
                // outside a Google Maps place card. Annotation `Button`s do NOT reliably consume
                // their tap before it reaches this gesture (see `suppressEmptyMapTapUntil`), so
                // taps inside the suppression window stamped by an annotation tap are ignored —
                // they're pass-through duplicates of that annotation tap, not real empty-area taps.
                .onTapGesture {
                    guard Date() >= suppressEmptyMapTapUntil else {
                        logEmptyMapTapSuppressed()
                        return
                    }
                    logEmptyMapAreaTapped()
                    viewModel.selectPin(nil)
                }

                if let selected = viewModel.selectedPin {
                    let anchor = popupAnchor(for: selected, mapSize: geo.size, cardHeight: mapDealCardHeight)
                    // `let _ = ...` (not a bare call) — this sits inside `ZStack`'s `@ViewBuilder`
                    // block, where a plain Void-returning expression statement would otherwise be
                    // treated as needing to conform to `View`.
                    let _ = logPopupPresentationReached(selected, anchor: anchor)

                    // Same `mapDealCard` instance stays mounted across marker switches
                    // (the `if let` only toggles on nil <-> non-nil, not on which pin is selected),
                    // so re-selecting a different marker animates this view to its new `anchor`
                    // instead of tearing it down and recreating it.
                    //
                    // Deliberately NOT wrapped in a navigation Button: only the card's own
                    // "View Deal" button navigates. Taps elsewhere on the card land on this
                    // gesture-less view and go nowhere — they neither navigate nor fall through
                    // to the map's empty-area tap gesture (the card is a ZStack sibling drawn
                    // above the map, not a child of it), so the popup also stays open.
                    mapDealCard(selected)
                    .frame(width: mapDealCardWidth(in: geo.size.width))
                    .background(
                        GeometryReader { cardGeo in
                            Color.clear
                                .preference(key: MapDealCardHeightPreferenceKey.self, value: cardGeo.size.height)
                        }
                    )
                    .position(anchor)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(edges: .bottom)
        .onPreferenceChange(MapDealCardHeightPreferenceKey.self) { height in
            guard height > 0 else { return }
            mapDealCardHeight = height
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPin)
        // `mapContent` is only mounted once `viewMode == .map`, by which point location has
        // often already resolved — `onAppear` covers that case; `onChange` covers location
        // resolving (or changing, e.g. via `ConfirmLocationScreen`) while the map is visible.
        // Pre-iOS-17 `onChange(of:perform:)` is used since this screen's deployment target is
        // below iOS 17.
        .onAppear {
            // The popup must never survive re-entering the map — returning from Deal Details
            // (back button or any other pop path) and list↔map toggles both land here, because
            // `onAppear` re-fires whenever this view is uncovered (same mechanism the screen's
            // `.task {}` relies on, per `HomeViewModel.onAppear`'s comment). Selecting a marker
            // again is the only way to bring the popup back.
            if viewModel.selectedPin != nil {
                logPopupDismissedOnMapReturn()
                viewModel.selectPin(nil)
            }
            // Center ONCE, on the first appearance that has a real location. Re-appearances
            // (returning from Deal Details, list↔map toggles) deliberately skip this so the
            // user's pan/zoom in `mapRegion` is preserved exactly — an unconditional sync here
            // is what used to snap the map back to the location on every return.
            if !hasCenteredMapOnUserLocation, viewModel.currentLocation != nil {
                syncMapRegion(from: viewModel.currentLocation)
                hasCenteredMapOnUserLocation = true
            }
        }
        // Fires only when the location genuinely changes (first GPS fix while the map is
        // visible, or a location manually confirmed on `ConfirmLocationScreen`) — never on
        // navigation returns, so it can't clobber a preserved pan/zoom state.
        .onChange(of: viewModel.currentLocation) { newValue in
            guard newValue != nil else { return }
            syncMapRegion(from: newValue)
            hasCenteredMapOnUserLocation = true
        }

        // TEMPORARY DEBUG — logs the popup's gating state (`selectedPin`) every time it changes,
        // including the exact reason the popup is absent when it's nil. Split into its own
        // statement (rather than chained directly above) so the type-checker resolves `baseMap`'s
        // type first — chaining it inline there made the whole modifier chain too complex for the
        // type-checker ("unable to type-check this expression in reasonable time"). Remove this,
        // and its call sites above, once the root cause is confirmed/fixed.
        return baseMap.onChange(of: viewModel.selectedPin) { newValue in
            logPopupStateChanged(newValue)
        }
    }

    // MARK: - TEMPORARY DEBUG — map popup investigation
    // Each of these is called as a single statement from inside a SwiftUI `ViewBuilder` closure
    // above, rather than inlining the `#if DEBUG`/multi-line `Logger` calls directly in those
    // closures — inlining them there made `mapContent`'s single giant ViewBuilder expression too
    // complex for the type-checker ("unable to type-check this expression in reasonable time").
    // Remove this whole section, and its call sites above, once the root cause is confirmed/fixed.

    /// Stamps the deadline before which the empty-map `.onTapGesture` treats an incoming tap as
    /// the pass-through duplicate of an annotation tap and ignores it — see
    /// `suppressEmptyMapTapUntil`. Called from every annotation (marker + cluster) tap action.
    private func suppressUpcomingEmptyMapTap() {
        suppressEmptyMapTapUntil = Date().addingTimeInterval(Self.emptyMapTapSuppressionWindow)
        #if DEBUG
        Logger.map.debug("""
            [MAP DEBUG] Annotation tap — suppressing the empty-map tap gesture for the next \
            \(Self.emptyMapTapSuppressionWindow, privacy: .public)s (pass-through duplicate guard).
            """)
        #endif
    }

    private func logViewDealTapped(_ pin: DealMapPin) {
        #if DEBUG
        Logger.map.debug("""
            [MAP DEBUG] "View Deal" button tapped — navigating to deal detail for \
            offerId=\(pin.id, privacy: .public), restaurantName=\(pin.restaurantName, privacy: .public). \
            This button is the popup's only navigation path — taps elsewhere on the card do nothing.
            """)
        #endif
    }

    private func logPopupDismissedOnMapReturn() {
        #if DEBUG
        Logger.map.debug("""
            [MAP DEBUG] Map re-appeared with a stale selection (returned from Deal Details or \
            switched back to map view) — dismissing the popup via selectPin(nil), per the \
            "no popup on return" rule.
            """)
        #endif
    }

    private func logEmptyMapTapSuppressed() {
        #if DEBUG
        Logger.map.debug("""
            [MAP DEBUG] Empty-map tap gesture fired inside the suppression window — it is the \
            pass-through duplicate of the annotation tap just handled, NOT a real empty-area tap. \
            selectPin(nil) NOT called; popup stays visible.
            """)
        #endif
    }

    private func logEmptyMapAreaTapped() {
        #if DEBUG
        Logger.map.debug("[MAP DEBUG] Empty map area tapped (outside suppression window) — calling viewModel.selectPin(nil) to dismiss popup.")
        #endif
    }

    private func logIndividualMarkerTapped(_ pin: DealMapPin) {
        #if DEBUG
        Logger.map.debug("""
            [MAP DEBUG] Marker tapped — INDIVIDUAL marker (not a cluster). \
            offerId(pin.id)=\(pin.id, privacy: .public), restaurantName=\(pin.restaurantName, privacy: .public), \
            offerTitle=\(pin.title, privacy: .public). Note: DealMapPin has no separate restaurantId field — \
            only the offer id is available here. Calling viewModel.selectPin(pin) now.
            """)
        #endif
    }

    private func logSelectPinCallbackReturned(_ pin: DealMapPin) {
        #if DEBUG
        Logger.map.debug("[MAP DEBUG] viewModel.selectPin(pin) callback returned for offerId=\(pin.id, privacy: .public).")
        #endif
    }

    private func logClusterMarkerTapped(_ cluster: MapCluster) {
        #if DEBUG
        Logger.map.debug("""
            [MAP DEBUG] Marker tapped — belongs to a CLUSTER. cluster.id=\(cluster.id, privacy: .public), \
            pinCount=\(cluster.count, privacy: .public), \
            containedOfferIds=\(cluster.pins.map(\.id), privacy: .public). \
            selectPin(_:) is NOT called for cluster taps — zoomToCluster(_:) runs instead, \
            so the deal popup will NOT open for this tap.
            """)
        #endif
    }

    private func logPopupPresentationReached(_ pin: DealMapPin, anchor: CGPoint) {
        #if DEBUG
        let existsInMapPins = viewModel.mapPins.contains(where: { $0.id == pin.id })
        Logger.map.debug("""
            [MAP DEBUG] Popup presentation method reached (mapDealCard) — \
            selectedPin.id=\(pin.id, privacy: .public), \
            restaurantName=\(pin.restaurantName, privacy: .public), \
            existsInMapPinsDataSource=\(existsInMapPins, privacy: .public), \
            popupAnchor=\(String(describing: anchor), privacy: .public). \
            Popup WILL be shown (no guard blocks this branch once selectedPin is non-nil).
            """)
        #endif
    }

    private func logPopupStateChanged(_ pin: DealMapPin?) {
        #if DEBUG
        if let pin {
            Logger.map.debug("""
                [MAP DEBUG] Popup state changed — isPopupVisible=true, selectedPin.id=\(pin.id, privacy: .public), \
                restaurantName=\(pin.restaurantName, privacy: .public).
                """)
        } else {
            Logger.map.debug("""
                [MAP DEBUG] Popup state changed — isPopupVisible=false (viewModel.selectedPin == nil). \
                Reason: either (a) no marker has been tapped yet, (b) the empty map area was tapped \
                (calls selectPin(nil)), or (c) the last tap landed on a CLUSTER marker — cluster taps \
                call zoomToCluster(_:) instead of selectPin(_:), so they never set selectedPin and the \
                popup never opens for that tap.
                """)
        }
        #endif
    }

    private func syncMapRegion(from location: LocationSnapshot?) {
        guard let location else { return }
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            span: Self.mapSpan
        )
    }

    /// Approximates the on-screen position of a map coordinate for the current `mapRegion` and
    /// viewport size. SwiftUI's `Map` has no public projection API pre-iOS 17 (`MapReader`/
    /// `MapProxy` are iOS 17+ only, and this screen still supports iOS 16 — see the `mapContent`
    /// fallback branch above), so this uses a linear equirectangular approximation instead. At
    /// the zoom levels Svangur's map operates in (region spans well under 1°), the distortion
    /// this introduces is negligible — accurate enough to anchor a popup to its marker.
    private func screenPoint(for coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        let latDelta = mapRegion.span.latitudeDelta
        let lonDelta = mapRegion.span.longitudeDelta
        guard latDelta > 0, lonDelta > 0, size.width > 0, size.height > 0 else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let xRatio = (coordinate.longitude - mapRegion.center.longitude) / lonDelta
        let yRatio = (mapRegion.center.latitude - coordinate.latitude) / latDelta

        return CGPoint(
            x: size.width * (0.5 + xRatio),
            y: size.height * (0.5 + yRatio)
        )
    }

    /// The popup's actual rendered width — capped at `mapDealCardWidth` but never wider than the
    /// map itself has room for (with margin on both sides). `popupAnchor` clamps against this
    /// exact same value, so the two can never disagree about how wide the card is.
    private func mapDealCardWidth(in mapWidth: CGFloat) -> CGFloat {
        min(Self.mapDealCardMaxWidth, max(mapWidth - Self.mapDealCardHorizontalMargin * 2, 0))
    }

    /// Places the popup card's center just above the selected marker (its bottom edge sits
    /// `SvSpacing.sm` above the marker's top edge), then clamps so the card never renders
    /// outside the visible map area — e.g. a marker near a screen edge still gets a fully
    /// on-screen popup instead of one clipped by the bounds. The horizontal clamp is derived
    /// from `mapDealCardWidth(in:)` — the same fixed-width calculation the card's `.frame(width:)`
    /// uses — rather than an async-measured size, so there's no frame where the two disagree and
    /// the card is drawn wider than the clamp assumes (which is what let it clip off-screen).
    private func popupAnchor(for pin: DealMapPin, mapSize: CGSize, cardHeight: CGFloat) -> CGPoint {
        let markerPoint = screenPoint(
            for: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
            in: mapSize
        )
        let markerHalfHeight = Self.mapMarkerHeight / 2
        let cardHalfWidth = mapDealCardWidth(in: mapSize.width) / 2
        let cardHalfHeight = cardHeight / 2
        let gap = SvSpacing.sm

        let rawX = markerPoint.x
        let rawY = markerPoint.y - markerHalfHeight - gap - cardHalfHeight

        let minX = cardHalfWidth + Self.mapDealCardHorizontalMargin
        let maxX = max(minX, mapSize.width - cardHalfWidth - Self.mapDealCardHorizontalMargin)
        let minY = cardHalfHeight + SvSpacing.md
        let maxY = max(minY, mapSize.height - cardHalfHeight - SvSpacing.md)

        return CGPoint(
            x: min(max(rawX, minX), maxX),
            y: min(max(rawY, minY), maxY)
        )
    }

    /// Reports the rendered height of the currently-visible `mapDealCard` back up to `mapContent`
    /// so `popupAnchor(for:mapSize:cardHeight:)` can center it vertically (SwiftUI has no way to
    /// query a sibling/child's laid-out size other than round-tripping it through a preference).
    /// Only height is tracked — width is fixed by `mapDealCardWidth(in:)`, see its comment.
    private struct MapDealCardHeightPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }

    private func clusterLabel(_ cluster: MapCluster) -> String {
        cluster.count == 1 ? cluster.pins[0].restaurantName : "\(cluster.count) deals"
    }

    @ViewBuilder
    private func mapAnnotationView(_ cluster: MapCluster) -> some View {
        if cluster.count == 1 {
            mapPinView(cluster.pins[0])
        } else {
            mapClusterView(cluster)
        }
    }

    private func mapClusterView(_ cluster: MapCluster) -> some View {
        Button {
            logClusterMarkerTapped(cluster)
            suppressUpcomingEmptyMapTap()
            zoomToCluster(cluster)
        } label: {
            ZStack {
                Image("Clustericon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                Text("\(cluster.count)")
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel("\(cluster.count) deals in this area")
    }

    /// Tapping a cluster zooms toward it instead of selecting a pin — halving the visible
    /// span (clamped to a sane minimum) re-runs clustering at the next render and naturally
    /// splits the group apart as pins spread out on screen.
    private func zoomToCluster(_ cluster: MapCluster) {
        withAnimation(.easeInOut(duration: 0.3)) {
            mapRegion = MKCoordinateRegion(
                center: cluster.coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: max(mapRegion.span.latitudeDelta * 0.4, 0.002),
                    longitudeDelta: max(mapRegion.span.longitudeDelta * 0.4, 0.002)
                )
            )
        }
    }

    private func mapPinView(_ pin: DealMapPin) -> some View {
        let isSelected = viewModel.selectedPin?.id == pin.id

        return Button {
            logIndividualMarkerTapped(pin)
            suppressUpcomingEmptyMapTap()
            viewModel.selectPin(pin)
            logSelectPinCallbackReturned(pin)
        } label: {
            mapMarkerImage(url: pin.imageUrl)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .accessibilityLabel("\(pin.restaurantName), \(pin.discountBadge) off")
        // `.overlay` keeps this label out of the button's own layout size, so it doesn't
        // shift the marker's `Annotation` anchor point (default `.center`) away from its
        // coordinate — the alignmentGuide override then pushes the label below the
        // marker's bottom edge instead of the flush placement `.overlay(alignment: .bottom)`
        // would otherwise give it.
        .overlay(alignment: .bottom) {
            mapPinLabel(pin)
                .alignmentGuide(.bottom) { d in d[.top] - SvSpacing.xxs }
                .accessibilityHidden(true)
        }
    }

    private static let markerTitleCharacterLimit = 12

    private func markerTitle(_ pin: DealMapPin) -> String {
        guard pin.restaurantName.count > Self.markerTitleCharacterLimit else { return pin.restaurantName }
        return String(pin.restaurantName.prefix(Self.markerTitleCharacterLimit)) + "..."
    }

    private func markerSubtitle(_ pin: DealMapPin) -> String {
        pin.dealCount == 1 ? "1 Deal" : "\(pin.dealCount) Deals"
    }

    private func mapPinLabel(_ pin: DealMapPin) -> some View {
        VStack(spacing: 0) {
            Text(markerTitle(pin))
                .font(SvFont.captionStrong)
                .foregroundStyle(Color.svOnBackground)
            Text(markerSubtitle(pin))
                .font(SvFont.caption)
                .foregroundStyle(Color.svSecondary)
        }
        .lineLimit(1)
        .truncationMode(.tail)
        // The `.overlay` hosting this label proposes the marker's own width (~44pt), so any
        // proposal-respecting width (`.frame(maxWidth:)`) collapsed to that and re-truncated
        // the title after a few characters. `.fixedSize()` sizes the label to its text
        // instead — bounded by design, since `markerTitle` caps the string at
        // `markerTitleCharacterLimit` (12) characters + "..." and the subtitle is "N Deals".
        .fixedSize()
        .padding(.horizontal, SvSpacing.xs)
        .padding(.vertical, SvSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .fill(Color.svSurface)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
    }

    /// `markerRestruent` is a full pin+pointer graphic with a circular cutout — sized here
    /// from the asset's own measured proportions (cutout is centered horizontally, ~64% of
    /// the marker's width in diameter, its top edge ~14.5% down from the marker's top edge)
    /// so the offer photo drops precisely into that cutout regardless of the marker's
    /// on-screen size.
    private func mapMarkerImage(url: URL?) -> some View {
        let markerWidth = Self.mapMarkerWidth
        let markerHeight = Self.mapMarkerHeight
        let circleDiameter = markerWidth * 0.64
        let circleTopInset = markerHeight * 0.145

        return Image("markerRestruent")
            .resizable()
            .frame(width: markerWidth, height: markerHeight)
            .overlay(alignment: .top) {
                dealCardImage(url: url)
                    .frame(width: circleDiameter, height: circleDiameter)
                    .clipShape(Circle())
                    .padding(.top, circleTopInset)
            }
    }

    private func mapDealCard(_ pin: DealMapPin) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            // MARK: - Top row: image · name/offer/hours · discount badge
            HStack(alignment: .top, spacing: SvSpacing.md) {
                dealCardImage(url: pin.imageUrl)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: SvSpacing.inputRadius))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SvSpacing.xxs) {
                    Text(pin.restaurantName)
                        .font(SvFont.labelTitle)
                        .foregroundStyle(Color.svLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(pin.title)
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(pin.validTimeText)
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                popupDiscountBadge(pin)
            }

            // MARK: - Distance (leading) + Open-now status (centered in the card, per design)
            // ZStack rather than an HStack+Spacers so the chip is centered on the card's full
            // width, independent of how wide the distance text happens to be.
            ZStack {
                HStack(spacing: SvSpacing.xs) {
                    Image("ic_pinLocation")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                    Text(popupDistanceText(pin))
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if pin.isOpenNow {
                    Text("Open now")
                        .font(SvFont.captionStrong)
                        .foregroundStyle(Color.svSuccess)
                        .padding(.horizontal, SvSpacing.sm)
                        .padding(.vertical, SvSpacing.xxs)
                        .background(Capsule().fill(Color.svSuccess.opacity(0.12)))
                }
            }

            // MARK: - View Deal (the popup's ONLY navigation affordance — the card
            // itself is deliberately not tappable, see `mapContent`)
            Button {
                logViewDealTapped(pin)
                router.navigate(to: .dealDetail(dealId: pin.id))
            } label: {
                Text("View Deal")
                    .font(SvFont.buttonText)
                    .foregroundStyle(Color.svOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                            .fill(Color.svPrimary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View deal for \(pin.restaurantName)")
        }
        .padding(SvSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                .fill(Color.svOnPrimary)
                .shadow(
                    color: .black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 0
                )
        )
    }

    /// The popup's compact top-right badge (smaller than the list card's `discountBadge`,
    /// per the popup design). Percent badges get the design's "X% off" wording; non-percent
    /// badge text ("2-for-1", "Free") is shown verbatim — appending "off" there reads wrong.
    private func popupDiscountBadge(_ pin: DealMapPin) -> some View {
        let badge = pin.discountBadge
        return Text(badge.hasSuffix("%") ? "\(badge) off" : badge)
            .font(SvFont.captionStrong)
            .foregroundStyle(Color.svOnPrimary)
            .padding(.horizontal, SvSpacing.sm)
            .padding(.vertical, SvSpacing.xxs)
            .background(Capsule().fill(Color.svPrimary))
            .fixedSize()
            .layoutPriority(1)
    }

    /// Distance from the user's current location to the pin's restaurant, computed live —
    /// the map-pins feed is fetched without lat/lng (see `loadMapPins`), so the server-side
    /// `pin.distance` is empty on the map. Falls back to that server value (which the mock
    /// pins populate) when the device location hasn't resolved yet.
    private func popupDistanceText(_ pin: DealMapPin) -> String {
        guard let location = viewModel.currentLocation else { return pin.distance }
        let user = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let restaurant = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        let km = user.distance(from: restaurant) / 1000
        return String(format: "%.1f km", km)
    }

    // MARK: - Food Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            Text("Food Categories")
                .font(SvFont.label)
                .foregroundStyle(Color.svLabel)
                .padding(.horizontal, SvSpacing.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.lg) {
                    // `categoryItem(label:)` takes a `Text` rather than a `String` so the
                    // static "All" option can go through the `LocalizedStringKey` catalog
                    // lookup (`Text("All")`, resolved via the `.environment(\.locale, ...)`
                    // set in `SvangurApp`) while server-localized category names stay verbatim.
                    categoryItem(
                        label: Text("All"),
                        accessibilityName: "All",
                        categoryId: nil,
                        imageName: "sandwich"
                    )
                    ForEach(viewModel.categories, id: \.id) { category in
                        // Fallback icon (used while `category.iconURL` loads and if it fails
                        // to load) is still keyed off `slug` via `categoryIconAssets(for:)` —
                        // unchanged from before this API-driven icon was added.
                        let icon = categoryIconAssets(for: category.slug)
                        let name = category.localizedName(for: languageService.current)
                        categoryItem(
                            label: Text(verbatim: name),
                            accessibilityName: name,
                            categoryId: category.id,
                            iconUrl: category.iconURL,
                            imageName: icon.imageName,
                            symbolName: icon.symbolName
                        )
                    }
                }
                .padding(.horizontal, SvSpacing.screenPadding)
            }
        }
        
    }
    

    private func categoryItem(
        label: Text,
        accessibilityName: String,
        categoryId: String?,
        iconUrl: URL? = nil,
        imageName: String? = nil,
        symbolName: String? = nil
    ) -> some View {
        let isSelected = viewModel.selectedCategoryId == categoryId

        return Button {
            let category = viewModel.categories.first { $0.id == categoryId }
            viewModel.selectCategory(category)
        } label: {
            VStack(spacing: SvSpacing.md) {

                ZStack(alignment: .topTrailing) {
                    categoryIcon(iconUrl: iconUrl, imageName: imageName, symbolName: symbolName)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? Color.svPrimary : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(Color.svPrimary)
                                .frame(width: 18, height: 18)

                            Image("Check")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 10, height: 10)
                        }
                        .offset(x: 4, y: -4)
                    }
                }
                .padding(.top, 4)

                label
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(
                        isSelected
                        ? Color.svPrimary
                        : Color.svOnBackground
                    )
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("\(accessibilityName) category")
    }

    /// JUDGMENT CALL: the real `/categories` list has no icon/image field, and only a handful of
    /// slugs have bundled photography (`burger`, `pizza`, `dish` for Asian). Any other slug falls
    /// back to a generic SF Symbol so newly added backend categories still render sensibly.
    private func categoryIconAssets(for slug: String) -> (imageName: String?, symbolName: String?) {
        switch slug {
        case "burgers", "burger": return ("burger", nil)
        case "pizza": return ("pizza", nil)
        case "asian": return ("dish", nil)
        case "sushi": return (nil, "fish.fill")
        case "mexican": return (nil, "flame.fill")
        default: return (nil, "fork.knife")
        }
    }

    /// Loads the category icon from the API's `icon_url` when present, via `AsyncImage` (the
    /// same image-loading approach used elsewhere in this screen, e.g. `dealCardImage(url:)`) —
    /// shimmer placeholder while it loads, existing bundled/SF-Symbol icon
    /// (`categoryIconFallback`) if the URL is missing or the load fails.
    @ViewBuilder
    private func categoryIcon(iconUrl: URL?, imageName: String?, symbolName: String?) -> some View {
        if let iconUrl {
            AsyncImage(url: iconUrl, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                case .empty:
                    Circle()
                        .fill(Color.svShimmer)
                        .svShimmer()
                case .failure:
                    categoryIconFallback(imageName: imageName, symbolName: symbolName)
                @unknown default:
                    categoryIconFallback(imageName: imageName, symbolName: symbolName)
                }
            }
        } else {
            categoryIconFallback(imageName: imageName, symbolName: symbolName)
        }
    }

    /// The pre-existing local/SF-Symbol icon rendering — unchanged, now also used as the
    /// on-failure/no-URL fallback for `categoryIcon(iconUrl:imageName:symbolName:)`.
    @ViewBuilder
    private func categoryIconFallback(imageName: String?, symbolName: String?) -> some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
        } else if let symbolName {
            Circle()
                .fill(Color.svPrimary.opacity(0.12))
                .overlay(
                    Image(systemName: symbolName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.svPrimary)
                )
        }
    }

    // MARK: - Discount Options

    private var discountSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            Text("Discount options")
                .font(SvFont.label)
                .foregroundStyle(Color.svLabel)
                .padding(.horizontal, SvSpacing.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.md) {
                    ForEach(viewModel.discountFilters, id: \.id) { filter in
                        discountChip(filter)
                    }
                }
                .padding(.horizontal, SvSpacing.screenPadding)
            }
        }
    }

    private func discountChip(_ filter: DiscountUserFilter) -> some View {
        let isSelected = viewModel.selectedDiscountFilterKey == filter.key
        // "All Offers" wraps onto two lines (e.g. "All" / "Offers") to match the chip's
        // square shape — any other multi-word label falls back to a single line.
        let labelWords = filter.key == "all" ? filter.label.split(separator: " ", maxSplits: 1) : []

        return Button {
            viewModel.selectDiscountFilter(filter)
        } label: {
            VStack(spacing: 0) {
                if labelWords.count == 2 {
                    Text(labelWords[0])
                        .font(SvFont.caption)
                    Text(labelWords[1])
                        .font(SvFont.labelTitle)
                } else {
                    Text(filter.label)
                        .font(SvFont.labelTitle)
                }
            }
            .padding(.horizontal, 8)
            .frame(width: 80, height: 64)
            .foregroundStyle(isSelected ? Color.white : Color.svOnBackground)
            .background(
                ZStack {
                    if isSelected {
                        LinearGradient(
                            colors: [
                                Color.svPrimaryGradientStart,
                                Color.svPrimaryGradientEnd
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.svPrimary.opacity(0.08)
                    }
                }
                    .shadow(
                        color: Color.svPrimaryGradientEnd.opacity(0.6),
                        radius: 2,
                        x: 0,
                        y: 0
                    )
                
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? Color.clear : Color("ECD3D9"), 
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.label)
    }
    // MARK: - Days of the Week

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text("Days of the week")
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)
                .padding(.horizontal, SvSpacing.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.sm) {
                    ForEach(viewModel.days, id: \.key) { day in
                        dayChip(day)
                    }
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.vertical, 6) // 👈 important
            }
        }
    }

    private func dayChip(_ day: DayItem) -> some View {
        let isSelected = viewModel.selectedDayKey == day.key
        let isToday = day.isToday

        let shape = RoundedRectangle(
            cornerRadius: 14,
            style: .continuous
        )

        return Button {
            viewModel.selectDay(day)
        } label: {
            // `day.shortLabel` is a dynamic, already-server-localized `String` (fetched with
            // the current `lang`) — kept verbatim. "Today" is static UI chrome, so it goes
            // through the `LocalizedStringKey` catalog lookup instead of being pre-computed
            // into a `String` (which silently skipped the catalog in an earlier attempt).
            Group {
                if isToday {
                    Text("Today")
                } else {
                    Text(verbatim: day.shortLabel)
                }
            }
                .font(SvFont.captionStrong)
                .padding(.horizontal, SvSpacing.lg)
                .frame(height: 38)
                .foregroundStyle(
                    isSelected
                    ? Color.white
                    : Color.svOnBackground
                )
                .background(
                    shape
                        .fill(
                            isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.svPrimaryGradientStart,
                                        Color.svPrimaryGradientEnd
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            : AnyShapeStyle(Color.svPrimary.opacity(0.08))
                        )
                )
                .overlay {
                    shape
                        .stroke(
                            isSelected
                            ? Color.clear
                            : Color("ECD3D9"),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: isSelected
                    ? Color.svPrimaryGradientEnd.opacity(0.30)
                    : Color.black.opacity(0.10),
                    radius: isSelected ? 6 : 4,
                    x: 0,
                    y: 2
                )
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isToday
            ? "Today, \(day.shortLabel)"
            : day.shortLabel
        )
    }
    
    // MARK: - All Deals

    private var dealsSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.lg) {
            HStack {
                Text("All Deals")
                    .font(SvFont.label)
                    .foregroundStyle(Color.svLabel)
                Spacer()
                HStack(spacing: SvSpacing.sm) {
                    Text("Open now")
                        .font(SvFont.labelTitleSmall)
                        .foregroundStyle(Color.svLabel)
                        .textCase(.uppercase)

                    SvCompactToggle(isOn: .init(
                        get: { viewModel.openNowOnly },
                        set: { _ in viewModel.toggleOpenNow() }
                    ))
                }
            }
            .padding(.horizontal, SvSpacing.screenPadding)
            dealsContent
        }
    }

    @ViewBuilder
    private var dealsContent: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            dealsSkeleton
        case .loaded(let deals):
            dealsList(deals)
        case .empty:
            emptyState
        case .error(let message):
            errorState(message)
        }
    }
    
    private struct SvCompactToggle: View {
        @Binding var isOn: Bool

        var activeColor: Color = .green

        private let trackWidth: CGFloat = 37
        private let trackHeight: CGFloat = 24
        private let thumbSize: CGFloat = 18
        private let trackPadding: CGFloat = 2

        private var thumbOffset: CGFloat {
            let travel = (trackWidth - thumbSize) / 2 - trackPadding
            return isOn ? travel : -travel
        }

        var body: some View {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isOn.toggle()
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(isOn ? activeColor : Color(.systemGray4))

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                        .offset(x: thumbOffset)
                }
                .frame(width: trackWidth, height: trackHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
        }
    }
    
    // MARK: - Deals List

    private func dealsList(_ deals: [DealCardUi]) -> some View {
        LazyVStack(spacing: SvSpacing.md) {
            ForEach(deals) { deal in
                Button {
                    router.navigate(to: .dealDetail(dealId: deal.id))
                } label: {
                    dealCard(from: deal)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, SvSpacing.screenPadding)
            }
        }
    }
    
    
    private func dealCard(from deal: DealCardUi) -> some View {
        HStack(spacing: 0) { // Set spacing to 0 to handle padding manually
            // MARK: - Left Image
            dealCardImage(url: deal.imageUrl)
            .frame(width: 130, height: 130) // Fixed height to maintain card consistency
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: SvSpacing.cardRadius,
                    bottomLeadingRadius: SvSpacing.cardRadius
                )
            )
            
            // MARK: - Right Content
            VStack(alignment: .leading, spacing: 4) {
                // Name + subtitle share the row with the badge so text can never run under it
                HStack(alignment: .top, spacing: SvSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(deal.restaurantName)
                            .font(SvFont.bodySmallStrong)
                            .foregroundStyle(Color.svLabel)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 4) {
                            Image("BowlFood") // Match "Japanskt" icon style
                                .font(.system(size: 10))
                            Text(deal.categoryName)
                                .font(SvFont.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(Color.svSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Invisible twin of the pinned badge — reserves its exact width in the
                    // text flow so the name/subtitle never enter the badge's corner area
                    discountBadge(deal.discountBadge)
                        .hidden()
                }

                Text(deal.title)
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(Color.svLabel)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                Text(deal.validTimeText)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svSecondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image("MapPin")
                        .font(.system(size: 10))
                    Text(deal.distance)
                        .font(SvFont.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(Color.svSecondary)
            }
            .padding(.leading, SvSpacing.md)
            .padding(.trailing, 10) // Same inset the pinned badge keeps from the card edge
            .padding(.vertical, 10) // Fixed top inset — identical whether the name is 1 or 2 lines
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 130)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                .fill(Color.svOnPrimary)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 0)
        )
        // MARK: - Pinned Discount Badge (drawn in the slot the hidden twin reserved)
        .overlay(alignment: .topTrailing) {
            discountBadge(deal.discountBadge)
                .padding([.top, .trailing], 10)
        }
    }

    // MARK: - Discount Badge
    private func discountBadge(_ text: String) -> some View {
        Text(text)
            .font(SvFont.captionStrong)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.svPrimary)
            )
            .fixedSize() // Badge keeps its natural size — surrounding text yields instead
            .layoutPriority(1)
    }

    /// Shimmer while the offer image loads, crossfade to the real image on success,
    /// and the bundled placeholder ONLY on failure. A nil URL goes straight to the
    /// placeholder — `AsyncImage` would otherwise sit in `.empty` (shimmer) forever.
    @ViewBuilder
    private func dealCardImage(url: URL?) -> some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.3))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                case .empty:
                    Rectangle()
                        .fill(Color.svShimmer)
                        .svShimmer()
                case .failure:
                    dealCardImageFallback
                @unknown default:
                    dealCardImageFallback
                }
            }
        } else {
            dealCardImageFallback
        }
    }

    private var dealCardImageFallback: some View {
        Image("SampleOfferBurgers")
            .resizable()
            .scaledToFill()
    }

    // MARK: - Skeleton
    private var dealsSkeleton: some View {
        VStack(spacing: SvSpacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: SvSpacing.md) {
                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                        .fill(Color.svShimmer)
                        .frame(width: 80, height: 80)
                    VStack(alignment: .leading, spacing: SvSpacing.sm) {
                        RoundedRectangle(cornerRadius: SvSpacing.xs)
                            .fill(Color.svShimmer)
                            .frame(height: 14)
                        RoundedRectangle(cornerRadius: SvSpacing.xs)
                            .fill(Color.svShimmer)
                            .frame(width: 140, height: 12)
                        RoundedRectangle(cornerRadius: SvSpacing.xs)
                            .fill(Color.svShimmer)
                            .frame(width: 80, height: 10)
                    }
                    Spacer(minLength: 0)
                }
                .padding(SvSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                        .fill(Color.svSurface)
                )
            }
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .redacted(reason: .placeholder)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: SvSpacing.sm) {
            Spacer().frame(height: SvSpacing.xxs)
            Image("nearbyIcon")
                .font(.system(size: 64))
                .foregroundStyle(Color.svPrimary.opacity(0.6))
                .frame(width: 120, height: 190)
                .background(
                    Circle()
                        .fill(Color.svPrimary.opacity(0.08))
                )
            Spacer().frame(height: SvSpacing.sm)
            Text("No deals available nearby")
                .font(SvFont.titleSmall)
                .foregroundStyle(Color.svOnBackground)
                .multilineTextAlignment(.center)

            Text("We couldn't find any active offers in your area. Try changing your location or check back later.")
                .font(SvFont.caption)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SvSpacing.xxxl)

            Spacer().frame(height: SvSpacing.sm)
            SvPrimaryButton(title: "Change Location") {
                router.navigate(to: .selectLocation)
            }
            .padding(.horizontal, SvSpacing.screenPadding)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: SvSpacing.lg) {
            Spacer().frame(height: SvSpacing.xxxl)
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.svError)
            Text(message)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.refresh() }
            }
            .font(SvFont.buttonLabel)
            .foregroundStyle(Color.svPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SvSpacing.screenPadding)
    }
}

// MARK: - Previews

#Preview("Home - Empty") {
    NavigationStack {
        HomeScreen(viewModel: .previewInstance(state: .empty))
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
    .environmentObject(LanguageService())
}

#Preview("Home - Loading") {
    NavigationStack {
        HomeScreen(viewModel: .previewInstance(state: .loading))
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
    .environmentObject(LanguageService())
}

#Preview("Home - Loaded") {
    NavigationStack {
        HomeScreen(viewModel: .previewInstance(state: .loaded([
            DealCardUi(
                id: 1, restaurantName: "Pizza Palace", title: "30% off all pizzas",
                discountBadge: "30%", categoryName: "Pizza", distance: "1.2 km",
                validTimeText: "11:00–22:00", imageUrl: nil, isOpenNow: true
            ),
            DealCardUi(
                id: 2, restaurantName: "Burger Joint", title: "2-for-1 burgers",
                discountBadge: "2-for-1", categoryName: "Burgers", distance: "2.5 km",
                validTimeText: "11:30–14:00", imageUrl: nil, isOpenNow: false
            ),
        ])))
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
    .environmentObject(LanguageService())
}

#Preview("Home - Map") {
    NavigationStack {
        HomeScreen(viewModel: {
            let vm = HomeViewModel.previewInstance(state: .empty)
            vm.viewMode = .map
            vm.selectPin(DealMapPin.mockPins.first)
            return vm
        }())
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
    .environmentObject(LanguageService())
}

#Preview("Home - Wide (no break)") {
    NavigationStack {
        HomeScreen(viewModel: .previewInstance(state: .empty))
    }
    .environmentObject(AppRouter())
    .environmentObject(UserSession(authRepository: MockAuthRepository()))
    .environmentObject(LanguageService())
    .frame(width: 1024, height: 1366)
}
