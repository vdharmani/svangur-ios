import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    // Placeholder until merchant profile is fetched from UserSession / GetUserProfileUseCase.
    let restaurantName: String = "The Golden Fork"
    let restaurantAvatarName: String = "SampleRestaurantAvatar"

    private(set) var isLoggingOut = false
    private(set) var errorMessage: String?

    private let logoutUseCase: LogoutUseCaseProtocol

    init(logoutUseCase: LogoutUseCaseProtocol) {
        self.logoutUseCase = logoutUseCase
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
        SettingsViewModel(logoutUseCase: FakeLogoutUseCase())
    }
}

private struct FakeLogoutUseCase: LogoutUseCaseProtocol {
    func execute() async throws(AppError) {}
}
