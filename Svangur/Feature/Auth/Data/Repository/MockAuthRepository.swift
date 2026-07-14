import Foundation

actor MockAuthRepository: AuthRepositoryProtocol {
    private let validEmail = "owner@svangur.is"
    private let validPassword = "password123"
    private var currentTokenValue: AuthToken?
    private var rememberedCredentialsValue: Credentials?

    func login(credentials: Credentials) async throws(AppError) -> AuthToken {
        try? await Task.sleep(for: .milliseconds(900))
        guard credentials.email == validEmail, credentials.password == validPassword else {
            throw .unauthorized(message: "Invalid email or password.")
        }
        let token = Self.makeToken(for: credentials.email)
        currentTokenValue = token
        return token
    }

    func registerRestaurant(_ registration: RestaurantRegistration) async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(900))
        guard registration.email != validEmail else {
            throw .validation(message: "This email is already registered.")
        }
        // Per option (a): stub success — real submission is async-approved by admin.
    }

    func logout() async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(200))
        currentTokenValue = nil
    }

    func requestPasswordReset(email: String) async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(700))
        // Always succeeds — server policy: don't leak whether the address exists.
    }

    func resetPassword(_ request: PasswordResetToken) async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(700))
        guard request.token == "demo-token" else {
            throw .validation(message: "This reset link is invalid or has expired.")
        }
    }

    func reviseDocument(note: String, documentData: Data, filename: String) async throws(AppError) {
        try? await Task.sleep(for: .milliseconds(700))
    }

    func currentToken() async -> AuthToken? { currentTokenValue }

    func rememberedCredentials() async -> Credentials? { rememberedCredentialsValue }

    func rememberCredentials(_ credentials: Credentials) async {
        rememberedCredentialsValue = credentials
    }

    func forgetRememberedCredentials() async {
        rememberedCredentialsValue = nil
    }

    nonisolated private static func makeToken(for email: String) -> AuthToken {
        AuthToken(
            token: UUID().uuidString,
            expiresAt: Date().addingTimeInterval(3600),
            ownerId: 0,
            ownerNameEn: "Mock Restaurant",
            ownerNameIs: "Mock Restaurant",
            ownerEmail: email,
            ownerStatus: "approved"
        )
    }
}
