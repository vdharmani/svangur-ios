import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var profile: RestaurantProfileUi?

    private(set) var isLoggingOut = false
    private(set) var errorMessage: String?

    private let logoutUseCase: LogoutUseCaseProtocol
    private let getRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol

    init(
        logoutUseCase: LogoutUseCaseProtocol,
        getRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol
    ) {
        self.logoutUseCase = logoutUseCase
        self.getRestaurantProfileUseCase = getRestaurantProfileUseCase
    }

    /// Always refetches — the profile can change server-side (e.g. after Edit Restaurant),
    /// so this screen reappearing must show the latest name/image rather than a cached one.
    func onAppear() async {
        if let restaurantProfile = try? await getRestaurantProfileUseCase.execute() {
            profile = restaurantProfile.toProfileUi()
        }
    }

    func logout() async {
        isLoggingOut = true
        defer { isLoggingOut = false }
        do throws(AppError) {
            try await logoutUseCase.execute()
            errorMessage = nil
        } catch {
            errorMessage = error.displayMessage
        }
    }

    func consumeError() {
        errorMessage = nil
    }
}

// MARK: - Preview Factory

extension SettingsViewModel {
    @MainActor
    static func previewInstance() -> SettingsViewModel {
        let vm = SettingsViewModel(
            logoutUseCase: FakeLogoutUseCase(),
            getRestaurantProfileUseCase: FakeGetRestaurantProfileUseCase()
        )
        vm.profile = RestaurantProfileUi(
            name: "The Golden Fork",
            description: "A perfect place for great food, warm vibes, and special offers.",
            imageURL: nil
        )
        return vm
    }
}

private struct FakeLogoutUseCase: LogoutUseCaseProtocol {
    func execute() async throws(AppError) {}
}

private struct FakeGetRestaurantProfileUseCase: GetRestaurantProfileUseCaseProtocol {
    func execute() async throws(AppError) -> RestaurantEditData {
        RestaurantEditData(
            nameEn: "The Golden Fork",
            nameIs: "Gullni Gaffall",
            adminEmail: "info@goldenfork.is",
            phoneNumber: "555-1234",
            descriptionEn: "A perfect place for great food, warm vibes, and special offers.",
            descriptionIs: "Fullkominn staður fyrir frábæran mat.",
            address: "Laugavegur 1",
            city: "Reykjavik",
            country: "Iceland",
            latitude: 64.1466,
            longitude: -21.9426,
            website: "https://goldenfork.is",
            openingHours: []
        )
    }
}
