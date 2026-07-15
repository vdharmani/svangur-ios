import Foundation

final class DIContainer: Sendable {

    // MARK: - Singletons (truly app-wide only)

    let apiClient: APIClientProtocol
    let networkMonitor: NetworkMonitorProtocol
    let keychainManager: KeychainManagerProtocol
    let locationService: LocationServiceProtocol
    let placesService: PlacesServiceProtocol
    let selectedLocationStore: SelectedLocationStoreProtocol
    private let sharedAuthRepository: AuthRepositoryProtocol
    private let sharedOfferRepository: OfferRepositoryProtocol

    init(
        apiClient: APIClientProtocol? = nil,
        networkMonitor: NetworkMonitorProtocol = NetworkMonitor(),
        keychainManager: KeychainManagerProtocol = KeychainManager(),
        locationService: LocationServiceProtocol = LocationService(),
        placesService: PlacesServiceProtocol = PlacesService(),
        selectedLocationStore: SelectedLocationStoreProtocol = SelectedLocationStore()
    ) {
        self.networkMonitor = networkMonitor
        self.keychainManager = keychainManager
        self.locationService = locationService
        self.placesService = placesService
        self.selectedLocationStore = selectedLocationStore
        // `apiClient`'s default can't reference the `keychainManager` parameter directly (Swift
        // default-parameter expressions can't see sibling parameters), so it's built here
        // instead — ensures APIClient and AuthRepositoryImpl share the exact same Keychain
        // instance/service rather than each defaulting their own.
        let resolvedApiClient = apiClient ?? APIClient(keychain: keychainManager)
        self.apiClient = resolvedApiClient
        self.sharedAuthRepository = AuthRepositoryImpl(apiClient: resolvedApiClient, keychain: keychainManager)
        self.sharedOfferRepository = OfferRepositoryImpl(apiClient: resolvedApiClient)
    }

    // MARK: - Feature: Auth

    func makeAuthRepository() -> AuthRepositoryProtocol {
        sharedAuthRepository
    }

    func makeValidateCredentialsUseCase() -> ValidateCredentialsUseCaseProtocol {
        ValidateCredentialsUseCase()
    }

    func makeLoginUseCase() -> LoginUseCaseProtocol {
        LoginUseCase(
            authRepository: makeAuthRepository(),
            validate: makeValidateCredentialsUseCase()
        )
    }

    func makeRegisterRestaurantUseCase() -> RegisterRestaurantUseCaseProtocol {
        RegisterRestaurantUseCase(
            authRepository: makeAuthRepository(),
            validate: makeValidateCredentialsUseCase()
        )
    }

    func makeLogoutUseCase() -> LogoutUseCaseProtocol {
        LogoutUseCase(authRepository: makeAuthRepository())
    }

    func makeRequestPasswordResetUseCase() -> RequestPasswordResetUseCaseProtocol {
        RequestPasswordResetUseCase(
            authRepository: makeAuthRepository(),
            validate: makeValidateCredentialsUseCase()
        )
    }

    func makeResetPasswordUseCase() -> ResetPasswordUseCaseProtocol {
        ResetPasswordUseCase(
            authRepository: makeAuthRepository(),
            validate: makeValidateCredentialsUseCase()
        )
    }

    func makeRememberedCredentialsUseCase() -> RememberedCredentialsUseCaseProtocol {
        RememberedCredentialsUseCase(authRepository: makeAuthRepository())
    }

    @MainActor
    func makeUserSession() -> UserSession {
        UserSession(authRepository: makeAuthRepository())
    }

    @MainActor
    func makeLanguageService() -> LanguageService {
        LanguageService()
    }

    @MainActor
    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(
            loginUseCase: makeLoginUseCase(),
            validate: makeValidateCredentialsUseCase(),
            rememberedCredentialsUseCase: makeRememberedCredentialsUseCase()
        )
    }

    @MainActor
    func makeRegisterRestaurantViewModel() -> RegisterRestaurantViewModel {
        RegisterRestaurantViewModel(
            registerUseCase: makeRegisterRestaurantUseCase(),
            validate: makeValidateCredentialsUseCase(),
            locationService: locationService,
            placesService: placesService
        )
    }

    @MainActor
    func makeForgotPasswordViewModel() -> ForgotPasswordViewModel {
        ForgotPasswordViewModel(
            requestResetUseCase: makeRequestPasswordResetUseCase(),
            validate: makeValidateCredentialsUseCase()
        )
    }

    @MainActor
    func makeResetPasswordViewModel(token: String) -> ResetPasswordViewModel {
        ResetPasswordViewModel(
            token: token,
            resetUseCase: makeResetPasswordUseCase(),
            validate: makeValidateCredentialsUseCase()
        )
    }

    // MARK: - Feature: Home

    func makeGetNearbyOffersUseCase() -> GetNearbyOffersUseCaseProtocol {
        GetNearbyOffersUseCase(offerRepository: makeOfferRepository())
    }

    func makeGetHomeDealsUseCase() -> GetHomeDealsUseCaseProtocol {
        GetHomeDealsUseCase(dealRepository: makeDealRepository())
    }

    @MainActor
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getHomeDealsUseCase: makeGetHomeDealsUseCase(),
            getCurrentLocationUseCase: makeGetCurrentLocationUseCase(),
            dealRepository: makeDealRepository(),
            getDaysUseCase: makeGetDaysUseCase(),
            selectedLocationStore: selectedLocationStore,
            deviceId: DeviceIdentifier.current()
        )
    }

    func makeGetCurrentLocationUseCase() -> GetCurrentLocationUseCaseProtocol {
        GetCurrentLocationUseCase(locationService: locationService)
    }

    @MainActor
    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(getNearbyOffersUseCase: makeGetNearbyOffersUseCase())
    }

    @MainActor
    func makeSelectLocationViewModel() -> SelectLocationViewModel {
        SelectLocationViewModel(placesService: placesService)
    }

    @MainActor
    func makeConfirmLocationViewModel(name: String, placeID: String?) -> ConfirmLocationViewModel {
        ConfirmLocationViewModel(
            placesService: placesService,
            selectedLocationStore: selectedLocationStore,
            name: name,
            placeID: placeID
        )
    }

    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            logoutUseCase: makeLogoutUseCase(),
            getRestaurantProfileUseCase: makeGetRestaurantProfileUseCase()
        )
    }

    @MainActor
    func makeDealDetailViewModel(dealId: Int64) -> DealDetailViewModel {
        DealDetailViewModel(dealId: dealId, getOfferUseCase: makeGetOfferUseCase())
    }

    // MARK: - Feature: Profile

    func makeUserRepository() -> UserRepositoryProtocol {
        MockUserRepository()
    }

    func makeGetUserProfileUseCase() -> GetUserProfileUseCaseProtocol {
        GetUserProfileUseCase(userRepository: makeUserRepository())
    }

    @MainActor
    func makeProfileViewModel(userId: String) -> ProfileViewModel {
        ProfileViewModel(
            getUserProfileUseCase: makeGetUserProfileUseCase(),
            userId: userId
        )
    }

    // MARK: - Feature: Offers

    func makeOfferRepository() -> OfferRepositoryProtocol {
        sharedOfferRepository
    }

    func makeGetMyOffersUseCase() -> GetMyOffersUseCaseProtocol {
        GetMyOffersUseCase(offerRepository: makeOfferRepository())
    }

    func makeGetOfferUseCase() -> GetOfferUseCaseProtocol {
        GetOfferUseCase(offerRepository: makeOfferRepository())
    }

    func makeValidateOfferDraftUseCase() -> ValidateOfferDraftUseCaseProtocol {
        ValidateOfferDraftUseCase()
    }

    func makeCreateOfferUseCase() -> CreateOfferUseCaseProtocol {
        CreateOfferUseCase(
            offerRepository: makeOfferRepository(),
            validateDraft: makeValidateOfferDraftUseCase()
        )
    }

    func makeUpdateOfferUseCase() -> UpdateOfferUseCaseProtocol {
        UpdateOfferUseCase(
            offerRepository: makeOfferRepository(),
            validateDraft: makeValidateOfferDraftUseCase()
        )
    }

    func makeDeleteOfferUseCase() -> DeleteOfferUseCaseProtocol {
        DeleteOfferUseCase(offerRepository: makeOfferRepository())
    }

    func makeGetOfferAnalyticsUseCase() -> GetOfferAnalyticsUseCaseProtocol {
        GetOfferAnalyticsUseCase(offerRepository: makeOfferRepository())
    }

    @MainActor
    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            getMyOffersUseCase: makeGetMyOffersUseCase(),
            deleteOfferUseCase: makeDeleteOfferUseCase(),
            getRestaurantProfileUseCase: makeGetRestaurantProfileUseCase()
        )
    }

    @MainActor
    func makeAddOfferViewModel(mode: AddOfferMode) -> AddOfferViewModel {
        AddOfferViewModel(
            mode: mode,
            getOfferUseCase: makeGetOfferUseCase(),
            createOfferUseCase: makeCreateOfferUseCase(),
            updateOfferUseCase: makeUpdateOfferUseCase(),
            validateDraftUseCase: makeValidateOfferDraftUseCase(),
            dealRepository: makeDealRepository(),
            getDaysUseCase: makeGetDaysUseCase()
        )
    }

    @MainActor
    func makeOfferDetailViewModel(offerId: Int64) -> OfferDetailViewModel {
        OfferDetailViewModel(
            offerId: offerId,
            getOfferUseCase: makeGetOfferUseCase(),
            deleteOfferUseCase: makeDeleteOfferUseCase()
        )
    }

    // MARK: - Feature: Deals

    func makeDealRepository() -> DealRepositoryProtocol {
        DealRepositoryImpl(apiClient: apiClient)
    }

    // MARK: - Feature: Search

    func makeSearchRepository() -> SearchRepositoryProtocol {
        SearchRepositoryImpl(apiClient: apiClient)
    }

    func makeSearchResultsRepository() -> SearchResultsRepositoryProtocol {
        SearchResultsRepositoryImpl(apiClient: apiClient)
    }

    // MARK: - Feature: Days

    func makeDaysRepository() -> DaysRepositoryProtocol {
        DaysRepositoryImpl(apiClient: apiClient)
    }

    func makeGetDaysUseCase() -> GetDaysUseCaseProtocol {
        GetDaysUseCase(daysRepository: makeDaysRepository())
    }

    // MARK: - Feature: Legal

    func makeLegalRepository() -> LegalRepositoryProtocol {
        LegalRepositoryImpl(apiClient: apiClient)
    }

    func makeGetLegalDocumentUseCase() -> GetLegalDocumentUseCaseProtocol {
        GetLegalDocumentUseCase(legalRepository: makeLegalRepository())
    }

    @MainActor
    func makeLegalViewModel(documentType: LegalDocumentType) -> LegalViewModel {
        LegalViewModel(documentType: documentType, getLegalDocumentUseCase: makeGetLegalDocumentUseCase())
    }

    // MARK: - Feature: Bootstrap

    func makeBootstrapRepository() -> BootstrapRepositoryProtocol {
        BootstrapRepositoryImpl(apiClient: apiClient)
    }

    // MARK: - Feature: Settings — Change Password

    func makeChangePasswordRepository() -> ChangePasswordRepositoryProtocol {
        ChangePasswordRepositoryImpl(apiClient: apiClient)
    }

    func makeChangePasswordUseCase() -> ChangePasswordUseCaseProtocol {
        ChangePasswordUseCase(changePasswordRepository: makeChangePasswordRepository())
    }

    @MainActor
    func makeChangePasswordViewModel() -> ChangePasswordViewModel {
        ChangePasswordViewModel(
            changePasswordUseCase: makeChangePasswordUseCase(),
            validate: makeValidateCredentialsUseCase()
        )
    }

    // MARK: - Feature: Settings — Delete Account

    func makeDeleteAccountRepository() -> DeleteAccountRepositoryProtocol {
        DeleteAccountRepositoryImpl(apiClient: apiClient)
    }

    // MARK: - Feature: Settings — Edit Restaurant

    func makeEditRestaurantRepository() -> EditRestaurantRepositoryProtocol {
        EditRestaurantRepositoryImpl(apiClient: apiClient)
    }

    func makeGetRestaurantProfileUseCase() -> GetRestaurantProfileUseCaseProtocol {
        GetRestaurantProfileUseCase(editRestaurantRepository: makeEditRestaurantRepository())
    }

    func makeUpdateRestaurantProfileUseCase() -> UpdateRestaurantProfileUseCaseProtocol {
        UpdateRestaurantProfileUseCase(editRestaurantRepository: makeEditRestaurantRepository())
    }

    @MainActor
    func makeEditRestaurantViewModel() -> EditRestaurantViewModel {
        EditRestaurantViewModel(
            getProfileUseCase: makeGetRestaurantProfileUseCase(),
            updateProfileUseCase: makeUpdateRestaurantProfileUseCase(),
            placesService: placesService
        )
    }

    // MARK: - Core: Token Refresh

    func makeRefreshRepository() -> RefreshRepositoryProtocol {
        RefreshRepositoryImpl(apiClient: apiClient)
    }
}
