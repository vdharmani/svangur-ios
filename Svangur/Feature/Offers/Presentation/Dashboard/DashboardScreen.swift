import SwiftUI

struct DashboardScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(AppRouter.self) private var router
    @State var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }

    private func compactLayout() -> some View {
        VStack(spacing: 0) {
            navigationBar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    restaurantHeader
                    addOfferButton
                    contentArea
                    
                }
            }
            .background(Color.svBackground.ignoresSafeArea())
            .refreshable { await viewModel.refresh() }
        }
        .background(Color.svBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .svErrorBanner(viewModel.actionErrorMessage)
        .task { await viewModel.onAppear() }
        .blur(radius: viewModel.offerIdToDelete != nil ? 2 : 0)
        .overlay {
            if viewModel.offerIdToDelete != nil {
                SvConfirmationDialog(
                    iconName: "DeleteOffer",
                    title: "Delete Offer",
                    message: "Are you sure you want to delete this offer? This action cannot be undone.",
                    primaryTitle: "Cancel",
                    secondaryTitle: "Delete",
                    onPrimary: { viewModel.cancelDelete() },
                    onSecondary: { Task { await viewModel.confirmDelete() } }
                )
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button {
                router.pop()
            } label: {
                HStack(spacing: SvSpacing.md) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Dashboard")
                        .font(SvFont.title)
                }
                .foregroundStyle(Color.svOnBackground)
            }
            .accessibilityLabel("Back")

            Spacer()

            Button {
                router.navigate(to: .settings)
            } label: {
                Image("SettingsIcon")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.svOnBackground)
                    .frame(width: 23, height: 23)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.sm)
    }

    // MARK: - Restaurant Header

    @ViewBuilder
    private var restaurantHeader: some View {
        if let profile = viewModel.profile {
            VStack(alignment: .leading, spacing: SvSpacing.md) {
                HStack(alignment: .center, spacing: SvSpacing.md) {
                    restaurantImage(profile)
                        .frame(width: 82, height: 82)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.svPrimary, lineWidth: 1.5)
                                .padding(-2)
                        )

                    VStack(alignment: .leading, spacing: SvSpacing.md){
                        Text(profile.name)
                            .font(SvFont.mainLabel)
                            .foregroundStyle(Color.black)
                        statsRow
                    }
                }
                Text(profile.description)
                    .font(SvFont.editLink)
                    .foregroundStyle(Color.svSecondary)
                    .padding(.top, SvSpacing.sm)
            }
            .padding(.horizontal, SvSpacing.screenPadding)
            .padding(.top, SvSpacing.lg)
        } else {
            restaurantHeaderSkeleton
        }
    }

    @ViewBuilder
    private func restaurantImage(_ profile: RestaurantProfileUi) -> some View {
        if let url = profile.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.svImagePlaceholder
            }
        } else {
            Color.svImagePlaceholder
        }
    }

    private var restaurantHeaderSkeleton: some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            HStack(alignment: .center, spacing: SvSpacing.md) {
                Circle()
                    .fill(Color.svShimmer)
                    .frame(width: 82, height: 82)
                VStack(alignment: .leading, spacing: SvSpacing.sm) {
                    RoundedRectangle(cornerRadius: SvSpacing.xs)
                        .fill(Color.svShimmer)
                        .frame(width: 140, height: 18)
                    RoundedRectangle(cornerRadius: SvSpacing.xs)
                        .fill(Color.svShimmer)
                        .frame(width: 200, height: 14)
                }
            }
            RoundedRectangle(cornerRadius: SvSpacing.xs)
                .fill(Color.svShimmer)
                .frame(height: 14)
                .padding(.top, SvSpacing.sm)
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.lg)
        .redacted(reason: .placeholder)
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: SvSpacing.lg) {
            statItem(value: profileViewsCount, label: "Profile Views")
            statItem(value: activeOffersCount, label: "Active Offers")
            statItem(value: totalOffersCount, label: "Total Offers")
        }
    }

    // The API has no restaurant-level "profile views" stat — show 0 rather than a fake number.
    private var profileViewsCount: String { "0" }

    private var activeOffersCount: String {
        if case .loaded(let offers) = viewModel.state {
            return "\(offers.filter(\.isActive).count)"
        }
        return "0"
    }

    private var totalOffersCount: String {
        if case .loaded(let offers) = viewModel.state {
            return "\(offers.count)"
        }
        return "0"
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.xxs) {
            Text(value)
                .font(SvFont.label)
                .foregroundStyle(Color.svOnBackground)
                .fixedSize()
            Text(label)
                .font(SvFont.caption)
                .foregroundStyle(Color.svSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
//        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.svDivider)
            .frame(width: 1, height: 32)
    }

    // MARK: - Add Offer Button

    private var addOfferButton: some View {
        Button {
            router.navigate(to: .addOffer)
        } label: {
            HStack {
                Spacer()
                Text("Add New Offer")
                    .font(SvFont.buttonText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Color.svPrimary)
            .frame(height: SvSpacing.buttonHeightSm)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.svPrimary.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.svPrimary.opacity(0.10))
            )
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.xl)
    }
    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .loading:
            skeletonContent
        case .loaded(let offers):
            offersContent(offers)
        case .empty:
            emptyState
        case .error(let message):
            errorState(message)
        }
    }

    // MARK: - Offers List

    private func offersContent(_ offers: [OfferUi]) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.lg) {
            Text("Manage Offers")
                .font(SvFont.title)
                .foregroundStyle(Color.svOnBackground)
                .padding(.horizontal, SvSpacing.screenPadding)
//                .padding(.bottom, SvSpacing.md)
            LazyVStack(spacing: SvSpacing.lg) {
                ForEach(offers) { offer in
                    offerCard(offer)
                        .padding(.horizontal, SvSpacing.screenPadding)
                        .onAppear {
                            if offer.id == offers.last?.id {
                                viewModel.loadMore()
                            }
                        }
                }
                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SvSpacing.lg)
                }
            }
            .padding(.bottom, SvSpacing.xxxl)
        }
        .padding(.top, SvSpacing.xxl)
    }

    private func offerCard(_ offer: OfferUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.xl) {
            Button {
                router.navigate(to: .dealDetail(dealId: offer.id))
            } label: {
                HStack(alignment: .top, spacing: SvSpacing.lg) {
                    offerImage(offer)

                    VStack(alignment: .leading, spacing: SvSpacing.xs) {
                        Text(offer.discountBadgeText)
                            .font(SvFont.editLink)
                            .foregroundStyle(Color.svLabel)

                        Text(offer.title)
                            .font(SvFont.label)
                            .foregroundStyle(Color.svOnBackground)
                            .lineLimit(1)

                        Text(offer.description)
                            .font(SvFont.caption)
                            .foregroundStyle(Color.svSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: SvSpacing.sm) {
                ForEach(offer.validDayNames, id: \.self) { day in
                    Text(day)
                        .font(SvFont.caption)
                        .foregroundStyle(Color.svOnBackground)
                        .padding(.horizontal, SvSpacing.sm)
                        .padding(.vertical, SvSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: SvSpacing.sm)
                                .fill(Color.svImagePlaceholder)
                        )
                }
                Spacer()

                HStack(spacing: SvSpacing.sm) {
                    Button {
                        router.navigate(to: .editOffer(offerId: offer.id))
                    } label: {
                        Text("Edit")
                            .font(SvFont.captionStrong)
                            .foregroundStyle(Color.svOnPrimary)
                            .padding(.horizontal, SvSpacing.lg)
                            .padding(.vertical, SvSpacing.xs)
                            .frame(minWidth: 65)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [.svPrimaryGradientStart, .svPrimaryGradientEnd],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .shadow(color: .black.opacity(0.07), radius: 1, x: 0, y: 3)
                    }
                    Button {
                        viewModel.requestDelete(id: offer.id)
                    } label: {
                        Text("Delete")
                            .font(SvFont.caption)
                            .foregroundStyle(Color("SvLabelColor"))
                            .padding(.horizontal, SvSpacing.lg)
                            .padding(.vertical, SvSpacing.xs)
                            .frame(minWidth: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.svPrimary.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.svPrimary.opacity(0.10), lineWidth: 1)
                                    )
                            )
                    }
                }
                .fixedSize()
            }
        }
        .padding(SvSpacing.lg)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        .shadow(color: .black.opacity(0.07), radius: 2, x: 0, y: 3)
        .shadow(color: .black.opacity(0.02), radius: 2, x: -2, y: 0)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 2, y: 0)
        .mask(
            Rectangle()
                .padding(.top, 12)
                .padding(.bottom, -20)
                .padding(.horizontal, -20)
        )
    }

    @ViewBuilder
    private func offerImage(_ offer: OfferUi) -> some View {
        if let url = offer.imageUrls.first {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    imagePlaceholder
                default:
                    // While loading, show a neutral shimmer rather than the "no image" stock
                    // photo — that stock photo flashing before the real one loads reads as the
                    // wrong image, not as a loading state.
                    RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                        .fill(Color.svShimmer)
                        .redacted(reason: .placeholder)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: SvSpacing.inputRadius))
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
            .fill(Color.svImagePlaceholder)
            .frame(width: 80, height: 80)
            .overlay(
                Image("BrunchDeal")
                    
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: SvSpacing.xl) {
            Image("NoActiveDeals")
                .foregroundStyle(Color.svPrimary.opacity(0.5))
                .frame(width: 140, height: 140)
                .background(
                    Circle()
                        .fill(Color.svPrimary.opacity(0.08))
                )
            VStack(spacing: SvSpacing.sm) {
                Text("No active deals")
                    .font(SvFont.title)
                    .foregroundStyle(Color.svOnBackground)
                    .padding(.top, SvSpacing.xxxl)

                Text("You haven't created any deals yet. Create an offer to attract more customers and drive more sales.")
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SvSpacing.screenPadding)
            }
        }
        .padding(.top, SvSpacing.xxxl * 3)
        .padding(.bottom, SvSpacing.xxxl)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: SvSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(Color.svError)

            Text(message)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)
                .multilineTextAlignment(.center)

            SvPrimaryButton(title: "Retry") {
                Task { await viewModel.refresh() }
            }
        }
        .padding(.horizontal, SvSpacing.screenPadding)
        .padding(.top, SvSpacing.xxxl)
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: SvSpacing.lg) {
            RoundedRectangle(cornerRadius: SvSpacing.xs)
                .fill(Color.svShimmer)
                .frame(width: 160, height: 20)
                .padding(.horizontal, SvSpacing.screenPadding)

            VStack(spacing: SvSpacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: SvSpacing.md) {
                        RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                            .fill(Color.svShimmer)
                            .frame(width: 80, height: 80)
                        VStack(alignment: .leading, spacing: SvSpacing.sm) {
                            RoundedRectangle(cornerRadius: SvSpacing.xs)
                                .fill(Color.svShimmer)
                                .frame(width: 80, height: 12)
                            RoundedRectangle(cornerRadius: SvSpacing.xs)
                                .fill(Color.svShimmer)
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: SvSpacing.xs)
                                .fill(Color.svShimmer)
                                .frame(width: 200, height: 12)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(SvSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                            .fill(Color.svSurface)
                    )
                    .padding(.horizontal, SvSpacing.screenPadding)
                }
            }
        }
        .padding(.top, SvSpacing.xxl)
        .redacted(reason: .placeholder)
    }
}

// MARK: - Previews

#Preview("Dashboard - Loaded") {
    NavigationStack {
        DashboardScreen(viewModel: .previewInstance(
            state: .loaded(MockOfferRepository.seed.map { $0.toUi() })
        ))
    }
    .environment(AppRouter())
}

#Preview("Dashboard - Loading") {
    NavigationStack {
        DashboardScreen(viewModel: .previewInstance(state: .loading))
    }
    .environment(AppRouter())
}

#Preview("Dashboard - Empty") {
    NavigationStack {
        DashboardScreen(viewModel: .previewInstance(state: .empty))
    }
    .environment(AppRouter())
}

#Preview("Dashboard - Error") {
    NavigationStack {
        DashboardScreen(viewModel: .previewInstance(state: .error("Network error")))
    }
    .environment(AppRouter())
}

#Preview("Dashboard - Wide (no break)") {
    NavigationStack {
        DashboardScreen(viewModel: .previewInstance(
            state: .loaded(MockOfferRepository.seed.map { $0.toUi() })
        ))
        .frame(width: 1024, height: 1366)
    }
    .environment(AppRouter())
}
