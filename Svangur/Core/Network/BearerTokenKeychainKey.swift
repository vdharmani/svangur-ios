import Foundation

/// The Keychain key both `APIClient` (reads, to attach `Authorization: Bearer`) and
/// `AuthRepositoryImpl` (writes, on login/logout) agree on. Kept as a raw string here — not
/// the full `CachedAuthTokenDTO` — so Core/Network doesn't depend on a Feature/Auth type.
enum BearerTokenKeychainKey {
    static let value = "auth.bearer_token"
}
