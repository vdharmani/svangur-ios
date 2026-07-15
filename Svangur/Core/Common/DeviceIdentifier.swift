import Foundation

/// A stable, anonymous per-install identifier sent as `device_id` on public feed/search
/// endpoints (the server uses it to de-duplicate impression/click tracking). Not sensitive or
/// auth-related, so `UserDefaults` — not Keychain — is the right store. Intentionally NOT
/// `identifierForVendor`: that resets when all of the vendor's apps are uninstalled, which
/// would silently reset a device's impression/recent-search history server-side.
enum DeviceIdentifier {
    private static let key = "sv_device_id"

    static func current() -> String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
