import Foundation

struct ChangePasswordRequestDTO: Codable, Sendable {
    let oldPassword: String
    let newPassword: String
    let confirmPassword: String

    enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
        case confirmPassword = "confirm_password"
    }
}
