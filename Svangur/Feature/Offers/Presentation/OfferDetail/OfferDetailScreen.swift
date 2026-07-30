import SwiftUI

struct OfferDetailScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var languageService: LanguageService
    @StateObject var viewModel: OfferDetailViewModel

    @State private var showDeleteConfirm = false

    init(viewModel: OfferDetailViewModel) {
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
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear

            case .loading:
                loadingState

            case .loaded(let offer):
                content(for: offer)

            case .deleted:
                VStack(spacing: SvSpacing.lg) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("Offer deleted")
                        .font(SvFont.label)
                        .foregroundStyle(Color.svOnBackground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    try? await Task.sleep(for: .milliseconds(700))
                    dismiss()
                }

            case .error(let message):
                errorState(message)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Delete this offer?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteOffer() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .svErrorBanner(viewModel.actionErrorMessage)
        .task { await viewModel.onAppear(lang: languageService.current.rawValue) }
        .onChange(of: languageService.current) { newValue in
            Task { await viewModel.onLanguageChange(lang: newValue.rawValue) }
        }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private func content(for offer: OfferUi) -> some View {
        VStack(spacing: 0) {
            // NOTE: the bottom bar is a plain VStack sibling, NOT `.safeAreaInset(edge: .bottom)`
            // — on iOS 26, safeAreaInset bars over a ScrollView pick up the system's automatic
            // "scroll edge effect" (a soft blur/shadow at the bar's top edge), which read as an
            // unwanted shadow/border above the buttons. A plain docked view has no such effect.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection(offer)
                    statsSection(offer)
                        .padding(.top, SvSpacing.sectionSpacing)
                    aboutSection(offer)
                        .padding(.top, SvSpacing.sectionSpacing)
                    validOnSection(offer)
                        .padding(.top, SvSpacing.sectionSpacing)
                    photosSection(offer)
                        .padding(.top, SvSpacing.sectionSpacing)
                    Spacer(minLength: SvSpacing.xxxl)
                }
                .svNoScrollBounce()
            }
            .ignoresSafeArea(.container, edges: .top)

            editDeleteBar(offer)
        }
    }

    // MARK: - Hero Section (image + overlaid title + floating chips)

    @ViewBuilder
    private func heroSection(_ offer: OfferUi) -> some View {
        VStack(spacing: 0) {
            heroImage(offer)
            actionRow(offer)
                .padding(.horizontal, 20)
                .offset(y: -22)
                .padding(.bottom, -22)
        }
    }

    @ViewBuilder
    private func heroImage(_ offer: OfferUi) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 423)
            .overlay {
                remoteImage(offer.imageUrls.first)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .frame(maxWidth: .infinity)
            }
            .overlay(alignment: .bottomLeading) {
                titleOverlay(offer)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                Button {
                    dismiss()
                } label: {
                    Image("ic_backCircle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white))
                        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                }
                .accessibilityLabel("Back")
                .padding(.leading, 20)
                .padding(.top, 56)
            }
    }

    // MARK: - Title Overlay (on hero image)

    @ViewBuilder
    private func titleOverlay(_ offer: OfferUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.xs) {
            if let restaurantName = offer.restaurantName {
                Text(restaurantName)
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(offer.title)
                .font(SvFont.heading)
                .foregroundStyle(.white)

            HStack(spacing: SvSpacing.sm) {
                Image("ic_mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text(offer.categoryDisplayText)
                    .font(SvFont.bodySmall)

                if !offer.isActive {
                    statusPill(offer)
                }
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func statusPill(_ offer: OfferUi) -> some View {
        Text(statusLabel(offer.status))
            .font(SvFont.captionStrong)
            .foregroundStyle(.white)
            .padding(.horizontal, SvSpacing.sm)
            .padding(.vertical, SvSpacing.xxs)
            .background(Color.white.opacity(0.25), in: Capsule())
    }

    private func statusLabel(_ status: OfferStatus?) -> String {
        (status?.rawValue ?? "unknown").replacingOccurrences(of: "_", with: " ").capitalized
    }

    // MARK: - Action Row (floating chip row over image bottom)

    @ViewBuilder
    private func actionRow(_ offer: OfferUi) -> some View {
        // A single uniform `spacing:` value (rather than a flexible `Spacer`) so the gap between
        // the discount pill and the first chip matches the gap between chips exactly, regardless
        // of how many of the conditional location/website/call chips actually render.
        HStack(alignment: .center, spacing: SvSpacing.sm) {
            // Content-hugging (text + padding) while the chips flex to share the leftover
            // width — on every iPhone width this leaves the badge slightly wider than each
            // individual chip, without hardcoding any widths.
            Text(offer.discountBadgeText)
                .font(SvFont.bodySmallStrong)
                .foregroundStyle(Color.svPrimary)
                .padding(.horizontal, SvSpacing.xl)
                .frame(height: 52)
                .background(Color.white, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                .layoutPriority(1)

            if let latitude = offer.latitude, let longitude = offer.longitude {
                actionChip(image: "MapPinArea", label: "Location") {
                    openInMaps(latitude: latitude, longitude: longitude, name: offer.title)
                }
            }

            if let website = offer.restaurantWebsite, let url = URL(string: website) {
                actionChip(image: "Globe", label: "Website") {
                    openURL(url)
                }
            }

            if let phone = offer.restaurantPhone, !phone.isEmpty {
                actionChip(image: "PhoneCall", label: "Call") {
                    call(phone)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func openInMaps(latitude: Double, longitude: Double, name: String) {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let url = URL(string: "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(encodedName)") else { return }
        openURL(url)
    }

    private func call(_ phone: String) {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else { return }
        openURL(url)
    }

    @ViewBuilder
    private func actionChip(image: String, label: String, action: @escaping () -> Void) -> some View {
        actionChip(label: label, action: action) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)   // Matches DealDetailScreen's action chip icons
        }
    }

    /// White capsule chips with flexible, equal widths: each chip's `maxWidth: .infinity`
    /// claims an equal share of whatever width the badge (which has `layoutPriority(1)`)
    /// leaves over, so the row fills the screen on every device without hardcoded widths.
    /// Icon stays centered; the whole capsule is tappable.
    @ViewBuilder
    private func actionChip(label: String, action: @escaping () -> Void, @ViewBuilder icon: () -> some View) -> some View {
        Button(action: action) {
            icon()
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    // MARK: - Stats Section (Views / Clicks)

    @ViewBuilder
    private func statsSection(_ offer: OfferUi) -> some View {
        if let analytics = offer.analytics {
            HStack(spacing: SvSpacing.md) {
                statCard(title: "Views", value: analytics.views, changePct: analytics.viewsChangePct, periodLabel: analytics.periodLabel)
                statCard(title: "Clicks", value: analytics.clicks, changePct: analytics.clicksChangePct, periodLabel: analytics.periodLabel)
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func statCard(title: LocalizedStringKey, value: Int, changePct: Int, periodLabel: String) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.xs) {
            Text(title)
                .font(SvFont.caption)
                .foregroundStyle(Color.svSecondary)

            Text(value.formatted())
                .font(SvFont.title)
                .foregroundStyle(Color.svOnBackground)

            HStack(spacing: SvSpacing.xxs) {
                Image(changePct >= 0 ? "UpGreenArrow" : "RedDownArrow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                Text("\(abs(changePct))% vs last \(periodLabel)")
                    .foregroundStyle(changePct >= 0 ? Color.svPositiveChange : Color.svError)
            }
            .font(SvFont.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SvSpacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 3)
        .shadow(color: .black.opacity(0.02), radius: 2, x: -2, y: 0)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 2, y: 0)
    }

    // MARK: - About Section

    @ViewBuilder
    private func aboutSection(_ offer: OfferUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            sectionHeader("About the Deal")

            Text(offer.description)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svOnBackground)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SvSpacing.lg)
                .background(Color.svPrimarySurface, in: RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Valid On Section

    @ViewBuilder
    private func validOnSection(_ offer: OfferUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            sectionHeader("Valid On")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.sm) {
                    ForEach(offer.validDayNames, id: \.self) { day in
                        Text(day)
                            .font(SvFont.bodySmallStrong)
                            .foregroundStyle(Color.svOnBackground)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, SvSpacing.lg)
                            .padding(.vertical, SvSpacing.sm)
                            .background(
                                Color.svFieldBackground,
                                in: RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Photos Section

    @ViewBuilder
    private func photosSection(_ offer: OfferUi) -> some View {
        if !offer.imageUrls.isEmpty {
            VStack(alignment: .leading, spacing: SvSpacing.md) {
                sectionHeader("Photos")

                GeometryReader { geo in
                    let spacing: CGFloat = SvSpacing.sm
                    let rightWidth = (geo.size.width - 2 * spacing) / 3
                    let leftWidth = geo.size.width - rightWidth - spacing

                    switch offer.imageUrls.count {
                    case 1:
                        HStack(spacing: spacing) {
                            photoTile(offer.imageUrls[0], height: leftWidth)
                                .frame(width: leftWidth)
                            Spacer(minLength: 0)
                        }

                    case 2:
                        HStack(spacing: spacing) {
                            photoTile(offer.imageUrls[0], height: geo.size.height)
                                .frame(width: leftWidth)
                            photoTile(offer.imageUrls[1], height: geo.size.height)
                                .frame(width: rightWidth)
                        }

                    default:
                        HStack(spacing: spacing) {
                            photoTile(offer.imageUrls[0], height: leftWidth)
                                .frame(width: leftWidth)

                            VStack(spacing: spacing) {
                                photoTile(offer.imageUrls[1], height: rightWidth)
                                    .frame(width: rightWidth)
                                photoTile(offer.imageUrls[2], height: rightWidth)
                                    .frame(width: rightWidth)
                            }
                        }
                    }
                }
                .aspectRatio(3 / 2, contentMode: .fit)
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func photoTile(_ url: URL, height: CGFloat) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                remoteImage(url)
            }
            .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
    }

    // MARK: - Remote Image (shimmer while loading, bundled fallback on failure)

    @ViewBuilder
    private func remoteImage(_ url: URL?) -> some View {
        if let url {
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.3))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                case .empty:
                    Rectangle()
                        .fill(Color.svShimmer)
                        .svShimmer()
                case .failure:
                    offerImageFallback
                @unknown default:
                    offerImageFallback
                }
            }
        } else {
            offerImageFallback
        }
    }

    private var offerImageFallback: some View {
        Image("OfferPreviewImage")
            .resizable()
            .aspectRatio(contentMode: .fill)
    }

    // MARK: - Section Header (title + trailing hairline)

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: SvSpacing.md) {
            Text(title)
                .font(SvFont.title)
                .foregroundStyle(Color.svOnBackground)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(Color.svDivider)
                .frame(height: 1)
        }
    }

    // MARK: - Bottom Edit / Delete Bar

    @ViewBuilder
    private func editDeleteBar(_ offer: OfferUi) -> some View {
        HStack(spacing: SvSpacing.md) {
            SvPrimaryButton(title: "Edit", isEnabled: !viewModel.isDeleting) {
                router.navigate(to: .editOffer(offerId: viewModel.offerId))
            }

            Button {
                showDeleteConfirm = true
            } label: {
                Group {
                    if viewModel.isDeleting {
                        ProgressView()
                            .tint(Color.svOnBackground)
                    } else {
                        Text("Delete")
                            .font(SvFont.buttonLabel)
                            .foregroundStyle(Color.svOnBackground)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: SvSpacing.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                        .fill(Color.svPrimary.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                                .stroke(Color.svPrimary.opacity(0.10), lineWidth: 1)
                        )
                )
            }
            .disabled(viewModel.isDeleting)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.vertical, SvSpacing.md)
        .background(Color.svBackground)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.svShimmer)
                    .frame(height: 290)

                VStack(alignment: .leading, spacing: SvSpacing.lg) {
                    RoundedRectangle(cornerRadius: SvSpacing.xs)
                        .fill(Color.svShimmer)
                        .frame(width: 120, height: 32)

                    RoundedRectangle(cornerRadius: SvSpacing.xs)
                        .fill(Color.svShimmer)
                        .frame(height: 20)

                    RoundedRectangle(cornerRadius: SvSpacing.xs)
                        .fill(Color.svShimmer)
                        .frame(width: 200, height: 20)

                    RoundedRectangle(cornerRadius: SvSpacing.xs)
                        .fill(Color.svShimmer)
                        .frame(height: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, SvSpacing.sectionSpacing)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Error State

    @ViewBuilder
    private func errorState(_ message: String) -> some View {
        VStack(spacing: SvSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(Color.svSecondary)
            Text(message)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            SvPrimaryButton(title: "Retry") {
                Task { await viewModel.refresh() }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Local token — promote to Color.svSuccess in the Asset Catalog when the design system
// gains a green palette (mirrors the same judgment call in `OfferPreviewScreen.swift`).
private extension Color {
    static let svPositiveChange = Color(red: 0.13, green: 0.59, blue: 0.36)
}

// MARK: - Previews

#Preview("Offer Detail - Loaded") {
    NavigationStack {
        OfferDetailScreen(viewModel: .previewInstance(
            state: .loaded(MockOfferRepository.seed[0].toUi(
                for: .english,
                categories: [DealCategory(id: "1", slug: "chinese", nameEn: "Chinese", nameIs: "Kínverskt", sortOrder: 0)],
                restaurantProfile: RestaurantEditData(
                    nameEn: "Bella Italia", nameIs: "Bella Italia",
                    adminEmail: "info@bellaitalia.is", phoneNumber: "+354 555 1234",
                    descriptionEn: "", descriptionIs: "",
                    address: "Laugavegur 1", city: "Reykjavik", country: "Iceland",
                    latitude: 64.1466, longitude: -21.9426,
                    website: "https://bellaitalia.is",
                    openingHours: []
                ),
                analytics: OfferAnalytics(
                    views: 1245, viewsChangePct: 12,
                    clicks: 158, clicksChangePct: -6,
                    mapActions: 42, mapActionsChangePct: 3,
                    callActions: 18, callActionsChangePct: 5,
                    websiteActions: 27, websiteActionsChangePct: -2,
                    period: "last_7_days"
                )
            ))
        ))
    }
    .environmentObject(AppRouter())
    .environmentObject(LanguageService())
}

#Preview("Offer Detail - Loading") {
    NavigationStack {
        OfferDetailScreen(viewModel: .previewInstance(state: .loading))
    }
    .environmentObject(AppRouter())
    .environmentObject(LanguageService())
}

#Preview("Offer Detail - Error") {
    NavigationStack {
        OfferDetailScreen(viewModel: .previewInstance(state: .error("Not found")))
    }
    .environmentObject(AppRouter())
    .environmentObject(LanguageService())
}

#Preview("Offer Detail - Wide (no break)") {
    NavigationStack {
        OfferDetailScreen(viewModel: .previewInstance(
            state: .loaded(MockOfferRepository.seed[0].toUi(for: .english))
        ))
    }
    .environmentObject(AppRouter())
    .environmentObject(LanguageService())
    .frame(width: 1024, height: 1366)
}
