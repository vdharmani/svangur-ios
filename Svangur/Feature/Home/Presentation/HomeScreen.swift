import SwiftUI
import MapKit

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
    @State private var mapRegion = MKCoordinateRegion(
        center: HomeScreen.fallbackMapCoordinate,
        span: HomeScreen.mapSpan
    )

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
    }

    private var listContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SvSpacing.xl) {
                categoriesSection
                discountSection
                daysSection
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
                            Image(viewModel.viewMode == .list ? "ic_Svlocation" : "ic_list")
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
                RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                    .fill(Color.svPink)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                    .stroke(Color.svDivider, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
                                                      
    // MARK: - Map View

    private var mapContent: some View {
        ZStack(alignment: .bottom) {
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
                        ForEach(viewModel.mapPins) { pin in
                            Annotation(pin.restaurantName, coordinate: CLLocationCoordinate2D(
                                latitude: pin.latitude, longitude: pin.longitude
                            )) {
                                mapPinView(pin)
                            }
                        }
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                } else {
                    // iOS 16 fallback — the legacy `Map(coordinateRegion:...)` initializer has no
                    // equivalent for `.mapControls` (compass / user-location button), so those are
                    // simply omitted here. Pin rendering + selection behavior is unchanged.
                    Map(
                        coordinateRegion: $mapRegion,
                        interactionModes: .all,
                        annotationItems: viewModel.mapPins
                    ) { pin in
                        MapAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: pin.latitude, longitude: pin.longitude
                        )) {
                            mapPinView(pin)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)

            if let selected = viewModel.selectedPin {
                Button {
                    router.navigate(to: .dealDetail(dealId: selected.id))
                } label: {
                    mapDealCard(selected)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.bottom, SvSpacing.xxxl)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPin)
        // `mapContent` is only mounted once `viewMode == .map`, by which point location has
        // often already resolved — `onAppear` covers that case; `onChange` covers location
        // resolving (or changing, e.g. via `ConfirmLocationScreen`) while the map is visible.
        // Pre-iOS-17 `onChange(of:perform:)` is used since this screen's deployment target is
        // below iOS 17.
        .onAppear { syncMapRegion(from: viewModel.currentLocation) }
        .onChange(of: viewModel.currentLocation) { newValue in
            syncMapRegion(from: newValue)
        }
    }

    private func syncMapRegion(from location: LocationSnapshot?) {
        guard let location else { return }
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            span: Self.mapSpan
        )
    }

    private func mapPinView(_ pin: DealMapPin) -> some View {
        let isSelected = viewModel.selectedPin?.id == pin.id

        return Button {
            viewModel.selectPin(pin)
        } label: {
            VStack(spacing: 0) {
                Image(pin.categoryImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.svPrimary : Color.white, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                Image(systemName: "triangle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(isSelected ? Color.svPrimary : .white)
                    .rotationEffect(.degrees(180))
                    .offset(y: -2)
            }
        }
        .accessibilityLabel("\(pin.restaurantName), \(pin.discountBadge) off")
    }

    private func mapDealCard(_ pin: DealMapPin) -> some View {
        HStack(spacing: 0) {

            // MARK: - Left Image
            Image(pin.categoryImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 130, height: 130)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: SvSpacing.cardRadius,
                        bottomLeadingRadius: SvSpacing.cardRadius
                    )
                )

            // MARK: - Right Content
            VStack(alignment: .leading, spacing: 4) {

                Text(pin.restaurantName)
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(Color.svLabel)

                HStack(spacing: 4) {
                    Image("BowlFood")
                        .resizable()
                        .frame(width: 12, height: 12)

                    Text("Burger Barn")
                        .font(SvFont.caption)
                }
                .foregroundStyle(Color.svSecondary)

                Text(pin.title)
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(Color.svLabel)
                    .lineLimit(1)
                    .padding(.top, 2)

                Text(pin.validTimeText)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svSecondary)

                HStack(spacing: 4) {
                    Image("MapPin")
                        .resizable()
                        .frame(width: 12, height: 12)

                    Text(pin.distance)
                        .font(SvFont.caption)
                }
                .foregroundStyle(Color.svSecondary)
            }
            .padding(.leading, SvSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .frame(height: 130)
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

        // MARK: - Discount Badge
        .overlay(alignment: .topTrailing) {
            Text(pin.discountBadge)
                .font(SvFont.captionStrong)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.svPrimary)
                )
                .padding([.top, .trailing], 10)
        }
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
                    categoryItem(name: "All", categoryId: nil, imageName: "sandwich")
                    ForEach(viewModel.categories, id: \.id) { category in
                        let icon = categoryIconAssets(for: category.slug)
                        categoryItem(
                            name: category.localizedName(for: languageService.current),
                            categoryId: category.id,
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
        name: String,
        categoryId: String?,
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
                    categoryIcon(imageName: imageName, symbolName: symbolName)
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

                Text(name)
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
        .accessibilityLabel("\(name) category")
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

    @ViewBuilder
    private func categoryIcon(imageName: String?, symbolName: String?) -> some View {
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
        let label = isToday ? "Today" : day.shortLabel

        let shape = RoundedRectangle(
            cornerRadius: 14,
            style: .continuous
        )

        return Button {
            viewModel.selectDay(day)
        } label: {
            Text(label)
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
                Text(deal.restaurantName)
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(Color.svLabel)
                
                HStack(spacing: 4) {
                    Image("BowlFood") // Match "Japanskt" icon style
                        .font(.system(size: 10))
                    Text(deal.restaurantName)
                        .font(SvFont.caption)
                }
                .foregroundStyle(Color.svSecondary)
                
                Text(deal.title)
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(Color.svLabel)
                    .lineLimit(1)
                    .padding(.top, 2)
                
                Text(deal.validTimeText)
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svSecondary)
                
                HStack(spacing: 4) {
                    Image("MapPin")
                        .font(.system(size: 10))
                    Text(deal.distance)
                        .font(SvFont.caption)
                }
                .foregroundStyle(Color.svSecondary)
            }
            .padding(.leading, SvSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                .fill(Color.svOnPrimary)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 0)
        )
        // MARK: - Top Right Badge Overlay
        .overlay(alignment: .topTrailing) {
            Text(deal.discountBadge)
                .font(SvFont.captionStrong)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.svPrimary)
                )
                .padding([.top, .trailing], 10)
        }
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
