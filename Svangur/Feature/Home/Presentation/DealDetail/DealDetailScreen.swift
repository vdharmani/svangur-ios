import SwiftUI

struct DealDetailScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @StateObject var viewModel: DealDetailViewModel
    @State private var showDeleteConfirmation = false

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
        .task { await viewModel.onAppear() }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private func dealContent(_ deal: DealDetailUi) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroSection(deal)
                statsRow
                    .padding(.top, SvSpacing.lg)
                aboutSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                validOnSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                photosSection(deal)
                    .padding(.top, SvSpacing.sectionSpacing)
                Spacer(minLength: SvSpacing.xxxl)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .blur(radius: showDeleteConfirmation ? 2 : 0)
        .overlay {
            if showDeleteConfirmation {
                SvConfirmationDialog(
                    iconName: "DeleteOffer",
                    title: "Delete Offer",
                    message: "Are you sure you want to delete this offer?",
                    primaryTitle: "Cancel",
                    secondaryTitle: "Delete",
                    onPrimary: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDeleteConfirmation = false
                        }
                    },
                    onSecondary: {
                        showDeleteConfirmation = false
                        // TODO: wire to viewModel.onDelete() when the use case is added
                    }
                )
                .transition(.opacity)
            }
        }
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
                Image(deal.heroImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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

    // MARK: - Stats Row
    // Placeholder values — extend DealDetailUi with views/clicks/trends when
    // the analytics model is wired up.

    @ViewBuilder
    private var statsRow: some View {
        HStack(spacing: SvSpacing.md) {
            statsCard(
                label: "VIEWS",
                value: "1,245",
                trendIcon: "arrow.up.right",
                trendText: "+12% vs last week",
                trendColor: Color.svTrendUp
            )
            statsCard(
                label: "CLICKS",
                value: "158",
                trendIcon: "arrow.down.right",
                trendText: "-6% vs last deal",
                trendColor: Color.svTrendDown
            )
        }
        .padding(.horizontal, 20)
    }

    private func statsCard(
        label: String,
        value: String,
        trendIcon: String,
        trendText: String,
        trendColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            Text(label)
                .font(SvFont.captionStrong)
                .foregroundStyle(Color.svSecondary)
                .tracking(1)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(Color.svOnBackground)

            HStack(spacing: SvSpacing.xs) {
                Image(systemName: trendIcon)
                    .font(.system(size: 11, weight: .bold))
                Text(trendText)
                    .font(SvFont.caption)
            }
            .foregroundStyle(trendColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SvSpacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
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

            HStack(spacing: SvSpacing.sm) {
                ForEach(deal.validDays, id: \.self) { day in
                    Text(day)
                        .font(SvFont.bodySmallStrong)
                        .foregroundStyle(Color.svOnBackground)
                        .padding(.horizontal, SvSpacing.lg)
                        .padding(.vertical, SvSpacing.sm)
                        .background(
                            Color.svFieldBackground,
                            in: RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Photos Section

    @ViewBuilder
    private func photosSection(_ deal: DealDetailUi) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            sectionHeader("Photos")

            if deal.photoImageNames.count >= 3 {
                GeometryReader { geo in
                    let spacing: CGFloat = SvSpacing.sm
                    let rightWidth = (geo.size.width - 2 * spacing) / 3
                    let leftWidth = geo.size.width - rightWidth - spacing

                    HStack(spacing: spacing) {
                        photoTile(deal.photoImageNames[0], height: leftWidth)
                            .frame(width: leftWidth)

                        VStack(spacing: spacing) {
                            photoTile(deal.photoImageNames[1], height: rightWidth)
                                .frame(width: rightWidth)
                            photoTile(deal.photoImageNames[2], height: rightWidth)
                                .frame(width: rightWidth)
                        }
                    }
                }
                .aspectRatio(3 / 2, contentMode: .fit)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func photoTile(_ name: String, height: CGFloat) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipShape(RoundedRectangle(cornerRadius: SvSpacing.cardRadius))
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

    // MARK: - Bottom Action Bar

    @ViewBuilder
    private var bottomActionBar: some View {
        HStack(spacing: SvSpacing.md) {
            SvPrimaryButton(title: "Edit") {
                router.navigate(to: .editOffer(offerId: viewModel.dealId))
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDeleteConfirmation = true
                }
            } label: {
                Text("Delete")
                    .font(SvFont.buttonLabel)
                    .foregroundStyle(Color.svOnBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: SvSpacing.buttonHeight)
                    .background(
                        Color.svFieldBackground,
                        in: RoundedRectangle(cornerRadius: SvSpacing.buttonRadius)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, SvSpacing.lg)
        .padding(.bottom, SvSpacing.md)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 24
            )
            .fill(Color.white)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -4)
            .ignoresSafeArea(.container, edges: .bottom)
        )
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

// Local trend tokens — promote to Color.svTrendUp / svTrendDown in the Asset
// Catalog when the design system gains a status-color palette.
private extension Color {
    static let svTrendUp   = Color(red: 0.13, green: 0.59, blue: 0.36)
    static let svTrendDown = Color(red: 0.91, green: 0.27, blue: 0.31)
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
