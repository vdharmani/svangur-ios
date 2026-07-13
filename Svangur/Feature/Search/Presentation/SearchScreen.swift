import SwiftUI

struct SearchScreen: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State var viewModel: SearchViewModel
    @FocusState private var isSearchFocused: Bool
    
    init(viewModel: SearchViewModel) {
        self._viewModel = State(wrappedValue: viewModel)
    }
    
    var body: some View {
        switch hSizeClass {
        case .regular: compactLayout()
        default:       compactLayout()
        }
    }
    
    // MARK: - Layout
    
    private func compactLayout() -> some View {
        VStack(spacing: 0) {
            searchHeader
            contentArea
        }
        .background(
            LinearGradient(
                colors: [Color.white,  Color.gray.opacity(0.6)],
                startPoint: UnitPoint(x: 0.5, y: 0.0),
                endPoint: UnitPoint(x: 0.5, y: 1.0)
            )
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear() }
        .onAppear { isSearchFocused = true }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        HStack(spacing: SvSpacing.sm) {
            Button {
                router.pop()
            } label: {
                Image("ic_Back")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.svOnBackground)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            
            TextField("Search...", text: $viewModel.query)
                .font(SvFont.body)
                .foregroundStyle(Color.svOnBackground)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onSubmit { viewModel.submitSearch() }
        }
        .padding(.trailing, SvSpacing.screenPadding)
        .padding(.vertical, SvSpacing.sm)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.state {
        case .idle:
            recentSearchesView
        case .noResults(let query):
            noResultsView(query: query)
        case .results(let results):
            searchResultsView(results)
        }
    }
    
    // MARK: - Recent Searches (Screen 1)
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: SvSpacing.sm) {
            if !viewModel.recentSearches.isEmpty {
                HStack {
                    Text("RECENT SEARCHES")
                        .font(SvFont.bodySmallStrong)
                        .foregroundStyle(Color.svSecondary)
                    
                    Spacer()
                    
                    Button {
                        viewModel.clearRecentSearches()
                    } label: {
                        Text("Clear")
                            .font(SvFont.bodySmallStrong)
                            .foregroundStyle(Color.svPrimary)
                    }
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.xl)
                
                recentSearchChips
            }
            
            Spacer()
        }
    }
    
    private var recentSearchChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SvSpacing.md) {
                ForEach(viewModel.recentSearches, id: \.self) { search in
                    Button {
                        viewModel.selectRecentSearch(search)
                    } label: {
                        HStack(spacing: SvSpacing.sm) {
                            Image("ic_recentTime")
                                .font(.system(size: 14))
                            Text(search)
                                .font(SvFont.bodySmall)
                        }
                        .padding(.horizontal, SvSpacing.md)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.svOnBackground)
                        .background(
                            RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.03), radius: 8, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SvSpacing.screenPadding)
            .padding(.vertical, SvSpacing.sm)
        }
    }
    
    // MARK: - No Results (Screen 2)
    
    private func noResultsView(query: String) -> some View {
        VStack(spacing: SvSpacing.xl) {
            Spacer()
            
            Image("ic_maginfyingGlass")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 250, height: 180)
            
            VStack(spacing: SvSpacing.sm) {
                Text("No restaurant found for \"\(query)\"")
                    .font(SvFont.titleSmall)
                    .foregroundStyle(Color.svLabel)
                    .multilineTextAlignment(.center)
                
                Text("We couldn't find any restaurants matching your search, please try another search or check your spelling.")
                    .font(SvFont.caption)
                    .foregroundStyle(Color.svSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SvSpacing.xxl)
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, SvSpacing.screenPadding)
    }
    
    // MARK: - Search Results (Screen 3)
    
    private func searchResultsView(_ results: [SearchResultUi]) -> some View {
        VStack(alignment: .leading, spacing: SvSpacing.lg) {
            Text("SEARCH RESULTS")
                .font(SvFont.captionStrong)
                .foregroundStyle(Color.svSecondary)
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.xl)
            
            ScrollView {
                LazyVStack(spacing: SvSpacing.md) {
                    ForEach(results) { result in
                        Button {
                            viewModel.submitSearch()
                            router.navigate(to: .dealDetail(dealId: result.id))
                        } label: {
                            searchResultCard(result)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SvSpacing.screenPadding)
                .padding(.top, SvSpacing.xs)
                .padding(.bottom, SvSpacing.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
 
    // MARK: - Search Result Card Components

    private func discountChip(_ text: String) -> some View {
        Text(text)
            .font(SvFont.captionStrong)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.svPrimaryGradientStart,
                                Color.svPrimaryGradientEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(6)
    }

    private func searchResultCard(_ result: SearchResultUi) -> some View {
        HStack(spacing: SvSpacing.md) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: result.imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        RoundedRectangle(cornerRadius: SvSpacing.inputRadius)
                            .fill(Color.svImagePlaceholder)
                            .overlay(
                                Image("SampleRestaurantAvatar")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.svSecondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 115, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: SvSpacing.inputRadius))
                discountChip("30% off")
            }
            
            VStack(alignment: .leading, spacing: SvSpacing.xs) {
                Text(result.restaurantName)
                    .font(SvFont.bodySmallStrong)
                    .foregroundStyle(Color.svLabel)
                
                Text(result.dealTitle)
                    .font(SvFont.captionStrong)
                    .foregroundStyle(Color.svLabel)
                    .lineLimit(1)
                
                HStack(spacing: SvSpacing.xs) {
                    Image("MapPin")
                        .font(.system(size: 10))
                    Text(result.distanceAndTime)
                        .font(SvFont.caption)
                }
                .foregroundStyle(Color.svSecondary)
            }
            .padding(.vertical, SvSpacing.md)
            
            Spacer(minLength: 0)
        }
        .background(
            RoundedRectangle(cornerRadius: SvSpacing.cardRadius)
                .fill(Color.svOnPrimary)
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
}
// MARK: - Previews

#Preview("Search - Initial") {
    NavigationStack {
        SearchScreen(viewModel: .previewInstance())
    }
    .environment(AppRouter())
    .environment(UserSession(authRepository: MockAuthRepository()))
}

#Preview("Search - No Results") {
    NavigationStack {
        SearchScreen(viewModel: .previewInstance(
            state: .noResults(query: "sushi")
        ))
    }
    .environment(AppRouter())
    .environment(UserSession(authRepository: MockAuthRepository()))
}

#Preview("Search - Results") {
    NavigationStack {
        SearchScreen(viewModel: .previewInstance(
            state: .results([
                SearchResultUi(
                    id: 1,
                    restaurantName: "Napoli Crust",
                    dealTitle: "30% off Margherita",
                    distanceAndTime: "12 km \u{2022} Mon - Sun 12:00 - 23:00",
                    imageUrl: nil
                ),
                SearchResultUi(
                    id: 2,
                    restaurantName: "Pizza Palace",
                    dealTitle: "Buy 2 Get 1 Free",
                    distanceAndTime: "18 km \u{2022} Fri - Sun 18:00 - 23:30",
                    imageUrl: nil
                ),
                SearchResultUi(
                    id: 3,
                    restaurantName: "Firewood Pizza Co.",
                    dealTitle: "25% off all pizzas",
                    distanceAndTime: "3 km \u{2022} Tue - Sun 17:00 - 23:30",
                    imageUrl: nil
                ),
            ])
        ))
    }
    .environment(AppRouter())
    .environment(UserSession(authRepository: MockAuthRepository()))
}

#Preview("Search - Dark") {
    NavigationStack {
        SearchScreen(viewModel: .previewInstance())
    }
    .environment(AppRouter())
    .environment(UserSession(authRepository: MockAuthRepository()))
    .preferredColorScheme(.dark)
}

#Preview("Search - Wide (no break)") {
    NavigationStack {
        SearchScreen(viewModel: .previewInstance(
            state: .results([
                SearchResultUi(
                    id: 1,
                    restaurantName: "Napoli Crust",
                    dealTitle: "30% off Margherita",
                    distanceAndTime: "12 km \u{2022} Mon - Sun 12:00 - 23:00",
                    imageUrl: nil
                ),
            ])
        ))
    }
    .environment(AppRouter())
    .environment(UserSession(authRepository: MockAuthRepository()))
    .frame(width: 1024, height: 1366)
}
