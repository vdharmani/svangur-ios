import SwiftUI

struct DealDetailScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var languageService: LanguageService
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
        Group {
            switch viewModel.state {
            case .idle:
                Color.clear

            case .loading:
                loadingState

            case .loaded(let deal):
                dealContent(deal)

            case .error(let message):
                errorState(message)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear(lang: languageService.current.rawValue) }
        .onChange(of: languageService.current) { newValue in
            Task { await viewModel.onLanguageChange(lang: newValue.rawValue) }
        }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private func dealContent(_ deal: DealDetailUi) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection(deal)
                aboutSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                validOnSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                photosSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                Spacer(minLength: SvSpacing.xxxl)
            }
            .svNoScrollBounce()
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
            .frame(height: 423)
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

            HStack(spacing: SvSpacing.sm) {
                Image("ic_mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
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

            if let latitude = deal.latitude, let longitude = deal.longitude {
                actionChip(image: "MapPinArea", label: "Location") {
                    openInMaps(latitude: latitude, longitude: longitude, name: deal.restaurantName)
                }
            }

            if let phone = deal.phone, !phone.isEmpty {
                actionChip(systemImage: "phone.fill", label: "Call") {
                    call(phone)
                }
            }
        }
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
    private func actionChip(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        actionChip(label: label, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.svPrimary)
        }
    }

    @ViewBuilder
    private func actionChip(image: String, label: String, action: @escaping () -> Void) -> some View {
        actionChip(label: label, action: action) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        }
    }

    @ViewBuilder
    private func actionChip(label: String, action: @escaping () -> Void, @ViewBuilder icon: () -> some View) -> some View {
        Button(action: action) {
            icon()
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
    private func photosSection(_ deal: DealDetailUi) -> some View {
        if !deal.photoImageUrls.isEmpty {
            VStack(alignment: .leading, spacing: SvSpacing.md) {
                sectionHeader("Photos")

                GeometryReader { geo in
                    let spacing: CGFloat = SvSpacing.sm
                    let rightWidth = (geo.size.width - 2 * spacing) / 3
                    let leftWidth = geo.size.width - rightWidth - spacing

                    switch deal.photoImageUrls.count {
                    case 1:
                        // Same size/shape as the "big" tile below — left-aligned, blank
                        // margin on the right rather than stretched full-width.
                        HStack(spacing: spacing) {
                            photoTile(deal.photoImageUrls[0], height: leftWidth)
                                .frame(width: leftWidth)
                            Spacer(minLength: 0)
                        }

                    case 2:
                        // Big tile + one on the right spanning the full row height.
                        HStack(spacing: spacing) {
                            photoTile(deal.photoImageUrls[0], height: geo.size.height)
                                .frame(width: leftWidth)
                            photoTile(deal.photoImageUrls[1], height: geo.size.height)
                                .frame(width: rightWidth)
                        }

                    default:
                        // Big tile + the next two stacked on the right. Extras beyond the
                        // first 3 aren't shown — matches the reference design.
                        HStack(spacing: spacing) {
                            photoTile(deal.photoImageUrls[0], height: leftWidth)
                                .frame(width: leftWidth)

                            VStack(spacing: spacing) {
                                photoTile(deal.photoImageUrls[1], height: rightWidth)
                                    .frame(width: rightWidth)
                                photoTile(deal.photoImageUrls[2], height: rightWidth)
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
    .environmentObject(LanguageService())
}

#Preview("Deal Detail - Loading") {
    NavigationStack {
        DealDetailScreen(viewModel: .previewInstance(state: .loading))
    }
    .environmentObject(LanguageService())
}

#Preview("Deal Detail - Error") {
    NavigationStack {
        DealDetailScreen(viewModel: .previewInstance(
            state: .error("Something went wrong")
        ))
    }
    .environmentObject(LanguageService())
}

#Preview("Deal Detail - Wide (no break)") {
    NavigationStack {
        DealDetailScreen(viewModel: .previewInstance(
            state: .loaded(.preview)
        ))
    }
    .environmentObject(LanguageService())
    .frame(width: 1024, height: 1366)
}
