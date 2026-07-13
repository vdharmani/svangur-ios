import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state: ProfileUiState = .idle

    private let getUserProfileUseCase: GetUserProfileUseCaseProtocol
    private let userId: String

    init(
        getUserProfileUseCase: GetUserProfileUseCaseProtocol,
        userId: String
    ) {
        self.getUserProfileUseCase = getUserProfileUseCase
        self.userId = userId
    }

    func onAppear() async {
        state = .loading
        do throws(AppError) {
            let user = try await getUserProfileUseCase.execute(id: userId)
            state = .success(user.toUi())
        } catch {
            state = .error(error.displayMessage)
        }
    }
}

// MARK: - Preview Factory

extension ProfileViewModel {
    @MainActor
    static func previewInstance(state: ProfileUiState = .idle) -> ProfileViewModel {
        let vm = ProfileViewModel(
            getUserProfileUseCase: FakeGetUserProfileUseCase(),
            userId: "preview-1"
        )
        vm.state = state
        return vm
    }
}

private struct FakeGetUserProfileUseCase: GetUserProfileUseCaseProtocol {
    func execute(id: String) async throws(AppError) -> User {
        User(
            id: id,
            name: "Preview User",
            email: "preview@svangur.is",
            avatarUrl: nil,
            memberSince: .now
        )
    }
}
