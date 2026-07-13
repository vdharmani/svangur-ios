import SwiftUI

struct SelectLocationScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State var viewModel: SelectLocationViewModel
    @FocusState private var searchFocused: Bool

    init(viewModel: SelectLocationViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
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
            LinearGradient(
                colors: [
                    Color.svOnPrimary,
                    Color.gray.opacity(0.4)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader

                VStack(alignment: .leading, spacing: SvSpacing.lg) {
                    searchField

                    if !viewModel.recentSearches.isEmpty {
                        recentSearchesSection
                    }

                    useCurrentLocationButton

                    resultsArea
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.sectionSpacing)

                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
    // MARK: - Header

    private var customHeader: some View {
        HStack(spacing: SvSpacing.sm) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.svOnBackground)
                    .frame(width: 10, height: 15, alignment: .leading)
            }
            .accessibilityLabel("Back")

            Text("Select Your Location")
                .font(SvFont.title)
                .foregroundStyle(Color.svOnBackground)

            Spacer()
        }
        .padding(.horizontal, SvSpacing.screenPadding)
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: SvSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.svSecondary)

            TextField("Search location", text: $viewModel.query)
                .font(SvFont.body)
                .foregroundStyle(Color.svOnBackground)
                .focused($searchFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
        }
        .padding(.horizontal, SvSpacing.lg)
        .frame(height: SvSpacing.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .fill(Color.svSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .stroke(Color.svDivider, lineWidth: 1)
        )
    }

    // MARK: - Recent searches

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: SvSpacing.md) {
            HStack {
                Text("RECENT SEARCHES")
                    .font(SvFont.captionStrong)
                    .foregroundStyle(Color.svSecondary)
                    .tracking(1)
                Spacer()
                Button {
                    viewModel.clearRecentSearches()
                } label: {
                    Text("Clear")
                        .font(SvFont.bodySmallStrong)
                        .foregroundStyle(Color.svPrimary)
                }
                .accessibilityLabel("Clear recent searches")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SvSpacing.sm) {
                    ForEach(viewModel.recentSearches, id: \.self) { name in
                        recentChip(name)
                    }
                }
            }
        }
    }

    private func recentChip(_ name: String) -> some View {
        Button {
            viewModel.selectRecent(name)
            router.navigate(to: .confirmLocation(name: name))
        } label: {
            HStack(spacing: SvSpacing.sm) {
                Image("ic_recentTime")
                    .font(.system(size: 14))

                Text(name)
                    .font(SvFont.bodySmall)
            }
            .padding(.horizontal, SvSpacing.md)
            .padding(.vertical, 10)
            .foregroundStyle(Color.svOnBackground)
            .background(
                RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                    .fill(Color.white)
                    .shadow(
                        color: .black.opacity(0.03),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                    .stroke(Color.svDivider.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
    

    // MARK: - Use current location

    private var useCurrentLocationButton: some View {
        Button {
            router.navigate(to: .confirmLocation(name: "Current location"))
        } label: {
                Text("📍  Use current location")
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(Color.svPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                Color.svFieldBackground,
                in: RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
            )
            .overlay(
                           RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                            .stroke(Color.svPrimary.opacity(0.2), lineWidth: 1)
                       )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use current location")
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsArea: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()

        case .results(let results):
            VStack(spacing: 0) {
                ForEach(results) { result in
                    Button {
                        viewModel.selectResult(result)
                        router.navigate(to: .confirmLocation(name: result.displayName))
                    } label: {
                        HStack(spacing: SvSpacing.md) {
                            Image(systemName: "mappin")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.svPrimary)
                                .frame(width: 24)
                            Text(result.displayName)
                                .font(SvFont.body)
                                .foregroundStyle(Color.svOnBackground)
                            Spacer()
                        }
                        .padding(.vertical, SvSpacing.md)
                    }
                    .buttonStyle(.plain)
                    Divider().background(Color.svDivider)
                }
            }

        case .noResults(let query):
            VStack(alignment: .leading, spacing: SvSpacing.sm) {
                Text("No matches for \"\(query)\"")
                    .font(SvFont.bodySmall)
                    .foregroundStyle(Color.svSecondary)
            }
            .padding(.top, SvSpacing.lg)
        }
    }
}

// MARK: - Previews

#Preview("Select Location - Default") {
    NavigationStack {
        SelectLocationScreen(viewModel: .previewInstance())
    }
}

#Preview("Select Location - Searching") {
    NavigationStack {
        SelectLocationScreen(viewModel: .previewInstance(
            query: "piz",
            state: .results([
                SelectLocationResultUi(id: "1", displayName: "Pizza Palace"),
                SelectLocationResultUi(id: "2", displayName: "Napoli Crust"),
                SelectLocationResultUi(id: "3", displayName: "Firewood Pizza Co.")
            ])
        ))
    }
}

#Preview("Select Location - No Results") {
    NavigationStack {
        SelectLocationScreen(viewModel: .previewInstance(
            query: "xyz",
            state: .noResults(query: "xyz")
        ))
    }
}

#Preview("Select Location - No Recents") {
    NavigationStack {
        SelectLocationScreen(viewModel: .previewInstance(recentSearches: []))
    }
}
