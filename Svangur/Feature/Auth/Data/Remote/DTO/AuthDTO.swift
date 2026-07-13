import Foundation

struct LoginRequestDTO: Codable, Sendable {
    let email: String
    let password: String
    let rememberMe: Bool
    let deviceToken: String
    let deviceType: String
    let deviceInfo: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case rememberMe = "remember_me"
        case deviceToken = "device_token"
        case deviceType = "device_type"
        case deviceInfo = "device_info"
    }

    init(
        email: String,
        password: String,
        rememberMe: Bool = true,
        deviceToken: String = "",
        deviceType: String = "ios",
        deviceInfo: String = ""
    ) {
        self.email = email
        self.password = password
        self.rememberMe = rememberMe
        self.deviceToken = deviceToken
        self.deviceType = deviceType
        self.deviceInfo = deviceInfo
    }
}

struct LoginOwnerDTO: Codable, Sendable {
    let id: Int64
    let nameEn: String
    let nameIs: String
    let email: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case nameEn = "name_en"
        case nameIs = "name_is"
        case email
        case status
    }
}

/// Verified live: `{ data: { token, expires_in, owner: {...} } }` — no `refresh_token`,
/// no `expires_at`, no top-level `user_id`.
struct LoginResponseDataDTO: Codable, Sendable {
    let token: String
    let expiresIn: Int
    let owner: LoginOwnerDTO

    enum CodingKeys: String, CodingKey {
        case token
        case expiresIn = "expires_in"
        case owner
    }
}

struct LoginResponseDTO: Codable, Sendable {
    let data: LoginResponseDataDTO
}

struct PasswordResetRequestDTO: Codable, Sendable {
    let email: String
}

struct PasswordResetConfirmDTO: Codable, Sendable {
    let token: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case token
        case newPassword = "new_password"
    }
}

// ─── Register ──────────────────────────────────────────────────────────────
// Verified live: { success, message, data: { owner_id, status } }.

struct RegisterDataDTO: Codable, Sendable {
    let ownerId: Int64
    let status: String

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case status
    }
}

struct RegisterResponseDTO: Codable, Sendable {
    let data: RegisterDataDTO
}
