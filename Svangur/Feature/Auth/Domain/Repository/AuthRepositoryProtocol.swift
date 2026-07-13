import Foundation

protocol AuthRepositoryProtocol: Sendable {
    func login(credentials: Credentials) async throws(AppError) -> AuthToken
    func registerRestaurant(_ registration: RestaurantRegistration) async throws(AppError)
    func logout() async throws(AppError)
    func requestPasswordReset(email: String) async throws(AppError)
    func resetPassword(_ request: PasswordResetToken) async throws(AppError)
    /// Resubmits the verification document — allowed only when the account status is
    /// `revision_requested`.
    func reviseDocument(note: String, documentData: Data, filename: String) async throws(AppError)
    func currentToken() async -> AuthToken?

    /// "Remember me" — persists/reads the raw email+password so the Login screen can be
    /// pre-filled. The password is sensitive, so this is Keychain-backed, never UserDefaults.
    func rememberedCredentials() async -> Credentials?
    func rememberCredentials(_ credentials: Credentials) async
    func forgetRememberedCredentials() async
}
