import SwiftUI

@MainActor
@Observable
final class ResetPasswordViewModel {
    var newPassword: String = "" { didSet { revalidateIfTouched() } }
    var confirmPassword: String = "" { didSet { revalidateIfTouched() } }

    private(set) var state: ResetPasswordUiState = .idle
    private(set) var validation = NewPasswordValidation()

    let token: String

    private var hasAttemptedSubmit = false

    private let resetUseCase: ResetPasswordUseCaseProtocol
    private let validate: ValidateCredentialsUseCaseProtocol

    init(
        token: String,
        resetUseCase: ResetPasswordUseCaseProtocol,
        validate: ValidateCredentialsUseCaseProtocol
    ) {
        self.token = token
        self.resetUseCase = resetUseCase
        self.validate = validate
    }

    var canSubmit: Bool {
        !newPassword.isEmpty && !confirmPassword.isEmpty && state != .submitting
    }

    func submit() async {
        hasAttemptedSubmit = true
        validation = validate.validateNewPassword(newPassword, confirm: confirmPassword)
        guard validation.isValid else { return }

        state = .submitting
        do throws(AppError) {
            try await resetUseCase.execute(token: token, newPassword: newPassword, confirm: confirmPassword)
            state = .success
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func revalidateIfTouched() {
        guard hasAttemptedSubmit else { return }
        validation = validate.validateNewPassword(newPassword, confirm: confirmPassword)
    }
}

extension ResetPasswordViewModel {
    @MainActor
    static func previewInstance(state: ResetPasswordUiState = .idle) -> ResetPasswordViewModel {
        let vm = ResetPasswordViewModel(
            token: "demo-token",
            resetUseCase: FakeResetUseCase(),
            validate: ValidateCredentialsUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeResetUseCase: ResetPasswordUseCaseProtocol {
    func execute(token: String, newPassword: String, confirm: String) async throws(AppError) {}
}
