import SwiftUI

@MainActor
@Observable
final class ForgotPasswordViewModel {
    var email: String = "" { didSet { revalidateIfTouched() } }

    private(set) var state: ForgotPasswordUiState = .idle
    private(set) var emailError: ValidationError?

    private var hasAttemptedSubmit = false

    private let requestResetUseCase: RequestPasswordResetUseCaseProtocol
    private let validate: ValidateCredentialsUseCaseProtocol

    init(
        requestResetUseCase: RequestPasswordResetUseCaseProtocol,
        validate: ValidateCredentialsUseCaseProtocol
    ) {
        self.requestResetUseCase = requestResetUseCase
        self.validate = validate
    }

    var canSubmit: Bool {
        !email.isEmpty && state != .submitting
    }

    func submit() async {
        hasAttemptedSubmit = true
        emailError = validate.validateEmailFormat(email)
        guard emailError == nil else { return }

        state = .submitting
        do throws(AppError) {
            try await requestResetUseCase.execute(email: email)
            state = .sent
        } catch {
            state = .error(error.displayMessage)
        }
    }

    private func revalidateIfTouched() {
        guard hasAttemptedSubmit else { return }
        emailError = validate.validateEmailFormat(email)
    }
}

extension ForgotPasswordViewModel {
    @MainActor
    static func previewInstance(state: ForgotPasswordUiState = .idle) -> ForgotPasswordViewModel {
        let vm = ForgotPasswordViewModel(
            requestResetUseCase: FakeRequestResetUseCase(),
            validate: ValidateCredentialsUseCase()
        )
        vm.state = state
        return vm
    }
}

private struct FakeRequestResetUseCase: RequestPasswordResetUseCaseProtocol {
    func execute(email: String) async throws(AppError) {}
}
