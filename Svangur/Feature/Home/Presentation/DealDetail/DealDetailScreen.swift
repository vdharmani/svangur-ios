import SwiftUI

struct DealDetailScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: DealDetailViewModel

    init(viewModel: DealDetailViewModel) {
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
        GeometryReader { geo in
            Group {
                switch viewModel.state {
                case .idle:
                    Color.clear

                case .loading:
                    loadingState

                case .loaded(let deal):
                    dealContent(deal, containerHeight: geo.size.height)

                case .error(let message):
                    errorState(message)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear() }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private func dealContent(_ deal: DealDetailUi, containerHeight: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection(deal)
                aboutSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                validOnSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                photosSection(deal, containerHeight: containerHeight)
                    .padding(.top, SvSpacing.sectionSpacing)
                Spacer(minLength: SvSpacing.xxxl)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - Hero Section (image + overlaid title + floating chips)

    @ViewBuilder
    private func heroSection(_ deal: DealDetailUi) -> some View {
        VStack(spacing: 0) {
            heroImage(deal)
            actionRow(deal)
                .padding(.horizontal, 20)
                .offset(y: -22)
                .padding(.bottom, -22)
        }
    }

    @ViewBuilder
    private func heroImage(_ deal: DealDetailUi) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .overlay {
                remoteImage(deal.heroImageUrl)
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
                titleOverlay(deal)
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
    private func titleOverlay(_ deal: DealDetailUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.xs) {
            Text(deal.restaurantName)
                .font(SvFont.heading)
                .foregroundStyle(.white)

            HStack(spacing: SvSpacing.xs) {
                Image("tag")
                    .font(.system(size: 12))
                Text(deal.categoryLabel)
                    .font(SvFont.bodySmall)
            }
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Row (floating chip row over image bottom)

    @ViewBuilder
    private func actionRow(_ deal: DealDetailUi) -> some View {
        HStack(spacing: SvSpacing.sm) {
            Text(deal.discountBadge)
                .font(SvFont.bodySmallStrong)
                .foregroundStyle(Color.svPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)

            actionChip(icon: "mappin.and.ellipse", label: "Location")
            actionChip(icon: "globe", label: "Website")
            actionChip(icon: "phone.fill", label: "Call")
        }
    }

    @ViewBuilder
    private func actionChip(icon: String, label: String) -> some View {
        Button { } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.svPrimary)
                .frame(width: 44, height: 44)
                .background(Color.white, in: Circle())
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .accessibilityLabel(label)
    }

    // MARK: - About Section

    @ViewBuilder
    private func aboutSection(_ deal: DealDetailUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            sectionHeader("About the Deal")

            Text(deal.description)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svOnBackground)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SvSpacing.lg)
                .background(
                    Color.svFieldBackground,
                    in: RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                )
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Valid On Section

    @ViewBuilder
    private func validOnSection(_ deal: DealDetailUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            sectionHeader("Valid On")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.sm) {
                    ForEach(deal.validDays, id: \.self) { day in
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
    private func photosSection(_ deal: DealDetailUi, containerHeight: CGFloat) -> some View {
        if !deal.photoImageUrls.isEmpty {
            VStack(alignment: .leading, spacing: SvSpacing.md) {
                sectionHeader("Photos")

                if deal.photoImageUrls.count == 1 {
                    photoTile(deal.photoImageUrls[0], height: containerHeight * 0.5)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: SvSpacing.sm), GridItem(.flexible())],
                        spacing: SvSpacing.sm
                    ) {
                        ForEach(deal.photoImageUrls, id: \.self) { url in
                            photoTile(url, height: containerHeight * 0.25)
                        }
                    }
                }
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
                    dealImageFallback
                @unknown default:
                    dealImageFallback
                }
            }
        } else {
            dealImageFallback
        }
    }

    private var dealImageFallback: some View {
        Image("SampleOfferBurgers")
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

// MARK: - Previews

#Preview("Deal Detail - Loaded") {
    NavigationStack {
        DealDetailScreen(viewModel: .previewInstance(
            state: .loaded(.preview)
        ))
    }
}

#Preview("Deal Detail - Loading") {
    NavigationStack {
        DealDetailScreen(viewModel: .previewInstance(state: .loading))
    }
}

#Preview("Deal Detail - Error") {
    NavigationStack {
        DealDetailScreen(viewModel: .previewInstance(
            state: .error("Something went wrong")
        ))
    }
}

#Preview("Deal Detail - Wide (no break)") {
    NavigationStack {
        DealDetailScreen(viewModel: .previewInstance(
            state: .loaded(.preview)
        ))
    }
    .frame(width: 1024, height: 1366)
}
