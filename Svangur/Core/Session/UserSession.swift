import SwiftUI
import Combine

@MainActor
final class UserSession: ObservableObject {
    @Published private(set) var token: AuthToken?
    @Published private(set) var isInitialized = false

    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    var isAuthenticated: Bool {
        guard let token else { return false }
        return !token.isExpired
    }

    func bootstrap() async {
        if let cached = await authRepository.currentToken(), !cached.isExpired {
            token = cached
        }
        isInitialized = true
    }

    func adopt(_ token: AuthToken) {
        self.token = token
    }

    func clear() {
        token = nil
    }
}
