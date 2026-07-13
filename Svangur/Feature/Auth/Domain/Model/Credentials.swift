import Foundation

struct Credentials: Sendable, Equatable, Codable {
    let email: String
    let password: String
}

struct PasswordResetToken: Sendable, Equatable {
    let token: String
    let newPassword: String
}
