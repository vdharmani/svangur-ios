import SwiftUI
import GooglePlacesSwift
import IQKeyboardManagerSwift
import IQKeyboardToolbarManager

@main
struct SvangurApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var session: UserSession
    @StateObject private var languageService: LanguageService
    private let container: DIContainer

    init() {
        PlacesClient.provideAPIKey(APIKeys.googlePlaces)

        // Keeps the focused text field visible above the keyboard and adds a
        // Previous/Next/Done toolbar app-wide, instead of hand-rolling keyboard-avoidance
        // per form screen.
        IQKeyboardManager.shared.isEnabled = true
        IQKeyboardManager.shared.resignOnTouchOutside = true
        IQKeyboardToolbarManager.shared.isEnabled = true

        let container = DIContainer()
        self.container = container
        self._session = StateObject(wrappedValue: container.makeUserSession())
        self._languageService = StateObject(wrappedValue: container.makeLanguageService())
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .environmentObject(router)
                .environmentObject(session)
                .environmentObject(languageService)
                // Bridges the in-app language toggle (`LanguageService`, unrelated to the
                // device's system language) into SwiftUI's localization lookup — without this,
                // `Text("...")`/`Localizable.xcstrings` always resolve against the system
                // locale, so toggling the flag in the header would only affect API `lang=`
                // params (server-returned data) and never the static UI chrome.
                .environment(\.locale, Locale(identifier: languageService.current.rawValue))
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    router.handle(url)
                }
        }
    }
}

private struct RootView: View {
    let container: DIContainer

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var session: UserSession
    @State private var splashFinished = false

    var body: some View {
        Group {
            if !splashFinished || !session.isInitialized {
                SplashScreen {
                    Task {
                        await session.bootstrap()
                        splashFinished = true
                    }
                    // Kicked off at launch, in parallel with the splash animation and session
                    // bootstrap, so `HomeViewModel.onAppear` doesn't have to wait for a fresh
                    // permission-check → GPS fix → reverse-geocode round trip once the user is
                    // already looking at Home. `getCurrentLocationUseCase` is a shared, caching
                    // singleton (see its doc comment), so this fetch's result — or the
                    // still-in-flight task itself — is exactly what Home consumes. Fire-and-forget:
                    // doesn't block the splash → app transition, and the system permission dialog
                    // can be answered (or dismissed) while the rest of startup proceeds.
                    Task {
                        _ = try? await container.getCurrentLocationUseCase.execute()
                    }
                }
            } else {
                NavigationStack(path: $router.path) {
                    HomeScreen(viewModel: container.makeHomeViewModel())
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationDestination(for: AppRoute.self) { route in
                            destinationView(for: route)
                                .toolbar(.hidden, for: .navigationBar)
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
        case .confirmLocation(let name, let placeID):
            ConfirmLocationScreen(viewModel: container.makeConfirmLocationViewModel(name: name, placeID: placeID))
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
        case .changePassword:
            ChangePasswordScreen(viewModel: container.makeChangePasswordViewModel())
        case .editRestaurant:
            EditRestaurantScreen(viewModel: container.makeEditRestaurantViewModel())
        case .onboarding:
            Text("Onboarding")
        case .legal(let documentType):
            LegalScreen(viewModel: container.makeLegalViewModel(documentType: documentType))
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
