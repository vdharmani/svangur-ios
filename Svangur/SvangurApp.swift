import SwiftUI
import GooglePlacesSwift

@main
struct SvangurApp: App {
    @State private var router = AppRouter()
    @State private var session: UserSession
    private let container: DIContainer

    init() {
        PlacesClient.provideAPIKey(APIKeys.googlePlaces)
        let container = DIContainer()
        self.container = container
        self._session = State(wrappedValue: container.makeUserSession())
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .environment(router)
                .environment(session)
                .onOpenURL { url in
                    router.handle(url)
                }
        }
    }
}

private struct RootView: View {
    let container: DIContainer

    @Environment(AppRouter.self) private var router
    @Environment(UserSession.self) private var session
    @State private var splashFinished = false

    var body: some View {
        @Bindable var router = router

        Group {
            if !splashFinished || !session.isInitialized {
                SplashScreen {
                    Task {
                        await session.bootstrap()
                        splashFinished = true
                    }
                    // Requested at launch per explicit product decision — doesn't block the
                    // splash → app transition; the system permission dialog can be answered
                    // (or dismissed) while the rest of startup proceeds.
                    Task {
                        _ = await container.locationService.requestWhenInUseAuthorization()
                    }
                }
            } else {
                NavigationStack(path: $router.path) {
                    HomeScreen(viewModel: container.makeHomeViewModel())
                        .toolbarVisibility(.hidden, for: .navigationBar)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                                .toolbarVisibility(.hidden, for: .navigationBar)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeScreen(viewModel: container.makeHomeViewModel())
        case .login:
            LoginScreen(viewModel: container.makeLoginViewModel())
        case .registerRestaurant:
            RegisterRestaurantScreen(viewModel: container.makeRegisterRestaurantViewModel())
        case .entry:
            EntryScreen(
                onLogin:  { router.navigate(to: .login) },
                onSignup: { router.navigate(to: .registerRestaurant) }
            )
        case .forgotPassword:
            ForgotPasswordScreen(viewModel: container.makeForgotPasswordViewModel())
        case .resetPassword(let token):
            ResetPasswordScreen(viewModel: container.makeResetPasswordViewModel(token: token))
        case .search:
            SearchScreen(viewModel: container.makeSearchViewModel())
        case .selectLocation:
            SelectLocationScreen(viewModel: container.makeSelectLocationViewModel())
        case .confirmLocation(let name):
            ConfirmLocationScreen(viewModel: container.makeConfirmLocationViewModel(name: name))
        case .dealList:
            Text("Deal List")
        case .dealDetail(let dealId):
            DealDetailScreen(viewModel: container.makeDealDetailViewModel(dealId: dealId))
        case .restaurantDetail(let restaurantId):
            Text("Restaurant \(restaurantId)")
        case .profile(let userId):
            ProfileScreen(viewModel: container.makeProfileViewModel(userId: userId))
        case .settings:
            SettingsScreen(viewModel: container.makeSettingsViewModel())
        case .onboarding:
            Text("Onboarding")
        case .dashboard:
            DashboardScreen(viewModel: container.makeDashboardViewModel())
        case .addOffer:
            AddOfferScreen(viewModel: container.makeAddOfferViewModel(mode: .create))
        case .editOffer(let offerId):
            AddOfferScreen(viewModel: container.makeAddOfferViewModel(mode: .edit(offerId: offerId)))
        case .offerDetail(let offerId):
            OfferDetailScreen(viewModel: container.makeOfferDetailViewModel(offerId: offerId))
        }
    }
}
