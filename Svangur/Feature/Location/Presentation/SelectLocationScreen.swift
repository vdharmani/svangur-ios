import SwiftUI

struct SelectLocationScreen: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @StateObject var viewModel: SelectLocationViewModel
    @FocusState private var searchFocused: Bool

    init(viewModel: SelectLocationViewModel) {
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

                    if viewModel.state == .searching {
                        searchingIndicator
                    }

                    // Recents and search results are mutually exclusive: recents show only
                    // while the field is empty (which also forces `state == .idle`, so the
                    // results area below is guaranteed empty at the same time). Search
                    // results take their place — below Use Current Location — once a
                    // search runs, and clearing the field brings recents back here.
                    if viewModel.query.isEmpty && !viewModel.recentSearches.isEmpty {
                        recentSearchesSection
                    }

                    useCurrentLocationButton

                    resultsArea
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.sectionSpacing)
                .animation(.easeInOut(duration: 0.2), value: viewModel.state)

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
                .onSubmit { viewModel.searchNow() }
        }
        .padding(.horizontal, SvSpacing.lg)
        .frame(height: SvSpacing.inputHeight)
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .fill(Color.white)
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
                    ForEach(viewModel.recentSearches) { item in
                        recentChip(item)
                    }
                }
            }
        }
    }

    private func recentChip(_ item: RecentLocationSearch) -> some View {
        Button {
            viewModel.selectRecent(item)
            // Carries the recent's original `placeID` so ConfirmLocation re-resolves the SAME
            // place (map, pin, address, coordinates) instead of falling back to the GPS fix.
            router.navigate(to: .confirmLocation(name: item.displayName, placeID: item.placeID))
        } label: {
            HStack(spacing: SvSpacing.sm) {
                Image("ic_recentTime")
                    .font(.system(size: 14))

                Text(item.shortDisplayName)
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
        .accessibilityLabel(item.displayName)
    }
    

    // MARK: - Use current location

    private var useCurrentLocationButton: some View {
        Button {
            router.navigate(to: .confirmLocation(name: "Current location", placeID: nil))
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
        // `.searching` renders as the inline indicator directly below the search field —
        // this area (below Use Current Location) only ever shows the outcome of a search.
        case .idle, .searching:
            EmptyView()

        case .results(let results):
            resultsList(results)

        case .noResults:
            Text("No locations found")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svSecondary)

        case .error(let message):
            Text(message)
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svError)
        }
    }

    // MARK: - Inline searching indicator (directly below the search field)

    private var searchingIndicator: some View {
        HStack(spacing: SvSpacing.sm) {
            ProgressView()
                .controlSize(.small)
                .tint(Color.svPrimary)
            Text("Searching…")
                .font(SvFont.bodySmall)
                .foregroundStyle(Color.svPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Searching locations")
    }

    // MARK: - Results list (white rounded card, title + locality rows)

    private func resultsList(_ results: [SelectLocationResultUi]) -> some View {
        VStack(spacing: 0) {
            ForEach(results) { result in
                Button {
                    viewModel.selectResult(result)
                    searchFocused = false
                    router.navigate(to: .confirmLocation(name: result.displayName, placeID: result.id))
                } label: {
                    VStack(alignment: .leading, spacing: SvSpacing.xxs) {
                        Text(result.title)
                            .font(SvFont.bodySmallStrong)
                            .foregroundStyle(Color.svOnBackground)
                        if !result.subtitle.isEmpty {
                            Text(result.subtitle)
                                .font(SvFont.caption)
                                .foregroundStyle(Color.svSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, SvSpacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(result.displayName)

                if result.id != results.last?.id {
                    Divider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                .stroke(Color.svDivider.opacity(0.6), lineWidth: 1)
        )
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
