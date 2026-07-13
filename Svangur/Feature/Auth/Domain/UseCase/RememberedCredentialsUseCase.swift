protocol RememberedCredentialsUseCaseProtocol: Sendable {
    func load() async -> Credentials?
    func remember(_ credentials: Credentials) async
    func forget() async
}

final class RememberedCredentialsUseCase: RememberedCredentialsUseCaseProtocol, Sendable {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func load() async -> Credentials? {
        await authRepository.rememberedCredentials()
    }

    func remember(_ credentials: Credentials) async {
        await authRepository.rememberCredentials(credentials)
    }

    func forget() async {
        await authRepository.forgetRememberedCredentials()
    }
}
