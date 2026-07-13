import SwiftUI

@MainActor
@Observable
final class ChangePasswordViewModel {
    var currentPassword: String = "" { didSet { revalidateIfTouched() } }
    var newPassword: String = ""     { didSet { revalidateIfTouched() } }
    var confirmPassword: String = "" { didSet { revalidateIfTouched() } }

    private(set) var state: ChangePasswordUiState = .idle
    private(set) var validation = ChangePasswordValidation()

    private var hasAttemptedSubmit = false

    private let changePasswordUseCase: ChangePasswordUseCaseProtocol
    private let validate: ValidateCredentialsUseCaseProtocol

    init(
        changePasswordUseCase: ChangePasswordUseCaseProtocol,
        validate: ValidateCredentialsUseCaseProtocol
    ) {
        self.changePasswordUseCase = changePasswordUseCase
        self.validate = validate
    }

    var canSubmit: Bool {
        !currentPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty && state != .submitting
    }

    func submit() async {
        hasAttemptedSubmit = true
        revalidate()
        guard validation.isValid else { return }

        state = .submitting
        do throws(AppError) {
            try await changePasswordUseCase.execute(
                currentPassword: currentPassword,
                newPassword: newPassword,
                confirmPassword: confirmPassword
            )
            state = .success
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func revalidateIfTouched() {
        guard hasAttemptedSubmit else { return }
        revalidate()
    }

    private func revalidate() {
        validation = validate.validateChangePassword(
            current: currentPassword,
            new: newPassword,
            confirm: confirmPassword
        )
    }
}

// MARK: - Preview Factory
extension ChangePasswordViewModel {
    @MainActor
    static func previewInstance(state: ChangePasswordUiState = .idle) -> ChangePasswordViewModel {
        let vm = ChangePasswordViewModel(
            changePasswordUseCase: FakeChangePasswordUseCase(),
            validate: ValidateCredentialsUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeChangePasswordUseCase: ChangePasswordUseCaseProtocol {
    func execute(currentPassword: String, newPassword: String, confirmPassword: String) async throws(AppError) {}
}
