import SwiftUI

@MainActor
@Observable
final class LoginViewModel {
    var email: String = "" { didSet { revalidateIfTouched() } }
    var password: String = "" { didSet { revalidateIfTouched() } }
    var rememberMe: Bool = false

    private(set) var loadState: LoginLoadState = .ready
    private(set) var validation = CredentialsValidation()
    private(set) var effect: LoginUiEffect?

    private var hasAttemptedSubmit = false

    private let loginUseCase: LoginUseCaseProtocol
    private let validate: ValidateCredentialsUseCaseProtocol
    private let rememberedCredentialsUseCase: RememberedCredentialsUseCaseProtocol

    init(
        loginUseCase: LoginUseCaseProtocol,
        validate: ValidateCredentialsUseCaseProtocol,
        rememberedCredentialsUseCase: RememberedCredentialsUseCaseProtocol
    ) {
        self.loginUseCase = loginUseCase
        self.validate = validate
        self.rememberedCredentialsUseCase = rememberedCredentialsUseCase
    }

    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && loadState != .submitting
    }

    /// Pre-fills the form from any previously "remembered" credentials. Triggered from the
    /// View's `.task { }` — never from `init`, per this project's no-side-effects-in-init rule.
    func onAppear() async {
        guard let remembered = await rememberedCredentialsUseCase.load() else { return }
        email = remembered.email
        password = remembered.password
        rememberMe = true
    }

    func submit() async {
        hasAttemptedSubmit = true
        validation = validate.validateLogin(email: email, password: password)
        guard validation.isValid else { return }

        loadState = .submitting
        do throws(AppError) {
            let credentials = Credentials(email: email, password: password)
            let token = try await loginUseCase.execute(credentials: credentials)
            if rememberMe {
                await rememberedCredentialsUseCase.remember(credentials)
            } else {
                await rememberedCredentialsUseCase.forget()
            }
            loadState = .ready
            effect = .loggedIn(token)
        } catch {
            loadState = .error(error.displayMessage)
        }
    }

    func consumeEffect() { effect = nil }

    private func revalidateIfTouched() {
        guard hasAttemptedSubmit else { return }
        validation = validate.validateLogin(email: email, password: password)
    }
}

// MARK: - Preview Factory

extension LoginViewModel {
    @MainActor
    static func previewInstance(loadState: LoginLoadState = .ready) -> LoginViewModel {
        let vm = LoginViewModel(
            loginUseCase: FakeLoginUseCase(),
            validate: ValidateCredentialsUseCase(),
            rememberedCredentialsUseCase: FakeRememberedCredentialsUseCase()
        )
        vm.loadState = loadState
        return vm
    }
}

private struct FakeLoginUseCase: LoginUseCaseProtocol {
    func execute(credentials: Credentials) async throws(AppError) -> AuthToken {
        AuthToken(
            token: "fake",
            expiresAt: Date().addingTimeInterval(3600),
            ownerId: 0,
            ownerNameEn: "Preview Restaurant",
            ownerNameIs: "Preview Restaurant",
            ownerEmail: credentials.email,
            ownerStatus: "approved"
        )
    }
}

private struct FakeRememberedCredentialsUseCase: RememberedCredentialsUseCaseProtocol {
    func load() async -> Credentials? { nil }
    func remember(_ credentials: Credentials) async {}
    func forget() async {}
}
